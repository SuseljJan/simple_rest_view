defmodule SimpleRestView do
  @moduledoc """
  Module takes care of creating a map which can be converted into json.
  Meant to be used to shorten views in Phoenix projects
  Available functions are:

  render_schema()
  -> Renders map based on fields of schema passed as first parameter and values of map passed as second parameter
  -> Third parameter is a keyword array which represent optional parameters:
    -> only - fields specified in only will be the only fields of schema to get rendered
    -> except - fields specified in except will be excluded from rendering. All other fields on schema will be rendered
    -> many - a boolean which determines if values passed in second parameter should be rendered as a single map or a list of maps, defaults to false (single map)
    -> include_timestamps - a boolean which determines whether to include timestamp fields (inserted_at, updated_at) in the rendered map, defaults to false
    -> add - enables adding fields. Can be specified in a format [field_name: {SchemaReference, :field_which_references_nested_schema, [options...]}] or as [field_name: (fn model -> end)]
  usage example: render_schema(User, user, only: [:id, :username], add: [custom_field: (fn user -> some_function(user.email))])

  render_wrapper()
  -> Wraps results in data tag

  render_paginated_wrapper()
  -> Works with :scrivener library


  Check github repo for more info.
  """

  @adding_keyword :add
  @include_timestamps_keyword :include_timestamps
  @only_keyword :only
  @except_keyword :except
  @many_keyword :many
  @timestamp_fields  [:inserted_at, :updated_at]


  @doc """
  Function renders all fields of a given schema into a map that can be converted into json.
  Optional parameters are [many: true/false, only: [:field1, :field2], except: [:field1, :field2], include_timestamps: true/false, add: [field: [f1: {SchemaReference, :field_name, options}, f2: (fn schema -> ... end), f3: %{...}]]]
  """
  def render_schema(schema_ref, schema_map, opt \\ []) do
    cond do
      opt[@many_keyword] == true -> render_many_schema(schema_ref, schema_map, opt)
      true -> render_single_schema(schema_ref, schema_map, opt)
    end
  end

  def render_wrapper(data) do
    %{data: data}
  end

  @doc """
  Wraps the result with pagination data obtained when using :scrivener library
  """
  def render_paginated_wrapper(data, query_result, opt \\ []) do
    %{data: data,
      page_number: value_or_nil(query_result, :page_number),
      page_size: value_or_nil(query_result, :page_size),
      total_entries: value_or_nil(query_result, :total_entries),
      total_pages: value_or_nil(query_result, :total_pages)}
    |> handle_base_fields(opt)
  end



  defp render_many_schema(schema_ref, schema_list_of_maps, opt) do
    schema_list_of_maps
    |> Enum.map(fn schema_map ->
      render_single_schema(schema_ref, schema_map, convert_options(schema_map, opt))
    end)
  end

  defp render_single_schema(schema_ref, schema_map, opt) do
    converted_opts = convert_options(schema_map, opt)

    schema_ref.__schema__(:fields)
    |> Enum.map(fn key -> {key, value_or_nil(schema_map, key)} end)
    |> Enum.reduce(%{}, fn {key, val}, acc -> Map.put(acc, key, val) end)
    |> handle_options(converted_opts)
  end

  @doc """
  Function takes care of converting data from current level and all nested levels
  into maps that can be send from server.
  This is where the magic happens!
  """
  defp convert_options(schema_map, opt) do
    if opt[@adding_keyword] != nil do

      opt[@adding_keyword]
      |> Enum.reduce(opt, fn adding_options, accumulated_options ->
        case adding_options do

          # Rendering nested field
          {key, {schema_ref, field_atom, inner_options}} ->
            renewed_adding_options = handle_rendering_nested_schema(key, schema_ref, schema_map, field_atom, inner_options)
            concatenate_options(accumulated_options, renewed_adding_options)

          # Rendering nested field without options passed
          {key, {schema_ref, field_atom}} ->
            renewed_adding_options = handle_rendering_nested_schema(key, schema_ref, schema_map, field_atom)
            concatenate_options(accumulated_options, renewed_adding_options)

          # Adding field with a custom function
          {key, callback} when is_function(callback) ->
            concatenate_options(accumulated_options, [{@adding_keyword, [{key, callback.(schema_map)}]}])

          _ -> accumulated_options

        end
      end)

    else
      opt
    end
  end

  defp concatenate_options(full_options, options_to_concat) do
    current_add = full_options[@adding_keyword]
    if current_add != nil do
      to_add = Keyword.merge(current_add, options_to_concat[@adding_keyword])

      {_, new_keyword_list} = Keyword.pop(full_options, @adding_keyword)

      new_keyword_list
      |> Keyword.put(@adding_keyword, to_add)
    else
      full_options ++ options_to_concat
    end
  end

  defp handle_rendering_nested_schema(key, schema_ref, schema_map, field_name, options \\ []) do
    schema_to_render = value_or_nil(schema_map, field_name)

    inner_schema = render_schema(schema_ref, schema_to_render, options)

    [{@adding_keyword, [{key, inner_schema}]}]
  end

  defp value_or_nil(map, key) do
    with {:ok, val} <- Map.fetch(map, key) do
      val
    else _ ->
      nil
    end
  end

  @doc """
  Function takes care of rendering a map based on options passed
  Doesn't handle rendering on nested fields
  """
  defp handle_options(map, opt) do
    map
    |> handle_base_fields(opt)
    |> handle_adding_fields(opt[@adding_keyword])
    |> handle_timestamps(opt[@include_timestamps_keyword])
  end

  defp handle_base_fields(map, opt) do
    cond do
      opt[@only_keyword] -> if is_atom(opt[@only_keyword]), do: map |> Map.take([opt[@only_keyword]]), else: map |> Map.take(opt[@only_keyword])
      opt[@except_keyword] -> if is_atom(opt[@except_keyword]), do: map |> Map.drop([opt[@except_keyword]]), else: map |> Map.drop(opt[@except_keyword])
      true -> map
    end
  end


  @doc """
  Functions handle adding fields which get passed in opt parameter.
  It doesn't convert values and doesn't handle adding for nested fields
  """
  defp handle_adding_fields(map, {key, value}),
       do: map |> Map.put(key, value)

  defp handle_adding_fields(map, list_of_key_values) when is_list(list_of_key_values),
       do: list_of_key_values |> Enum.reduce(map, fn key_value_pair, acc -> handle_adding_fields(acc, key_value_pair) end)

  defp handle_adding_fields(map, _), do: map


  defp handle_timestamps(map, true), do: map

  defp handle_timestamps(map, false), do: map |> Map.drop(@timestamp_fields)

  defp handle_timestamps(map, _), do: handle_timestamps(map, false)

end
