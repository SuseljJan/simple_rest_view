defmodule SimpleRestView do
  alias User

  @moduledoc """
  Module takes care of creating concise views in Phoenix REST projects.\n
  It makes it possible to render nested JSON objects and limit which fields to render within the same function.
  """

  @adding_keyword :add
  @include_timestamps_keyword :include_timestamps
  @only_keyword :only
  @except_keyword :except
  @many_keyword :many
  @timestamp_fields  [:inserted_at, :updated_at]


  @doc """
  Function renders all fields which exist on a given schema into a map that can be converted into json.
  It supports rendering fields of nested objects if specified with add optional parameter.\n
  Optional parameters are:\n
  many - true/false\n
  only - [:field1, :field2]\n
  except - [:field1, :field2]\n
  include_timestamps - true/false\n
  add -
  * [field_name: {SchemaReference, :field_on_schema_map}] OR
  * [field_name: {SchemaReference, :field_on_schema_map, opt}] OR
  * [field_name: (fn schema -> ... end)] OR
  * [field_name: %{custom_field: custom_val, ...}]

  ## Examples

      iex> user = %User{id: 1, username: "joe", email: "joe@mail.com", password: "passwordhash123"}
      iex> render_schema(User, user)
      %{id: 1, username: "joe", email: "joe@mail.com", password: "passwordhash123"}


      iex> user = %User{
      ...>  id: 1,
      ...>  username: "joe",
      ...>  email: "joe@mail.con",
      ...>  password: "password123",
      ...>  reviewed: [%Review{...}, %Review{...}]
      ...> }
      iex> render_schema(User, user,
      ...>    except: [:email, :password],
      ...>    add: [
      ...>        avg_rating: (fn user -> get_avg_rating(user.id)),
      ...>        reviewed: {Review, :reviewed, many: true, only: [:comment]}
      ...>      ]
      ...>    )
      %{id: 1,
        username: "joe",
        avg_rating: 10,
        reviewed: [%{comment: "..."}, %{comment: "..."}]}


      iex> user = %User{
      ...> id: 1,
      ...> username: "joe",
      ...> email: "joe@mail.com",
      ...> password: "passwordhash123",
      ...> reviewed: [
      ...>    %Review{id: 1, comment: "...", ... , reviewer: %User{username: "mary", ...}},
      ...>    %Review{id: 2, comment: "...", ... , reviewer: %User{username: "johnson", ...}}
      ...> ]}
      iex> render_schema(User, user,
      ...>    except: [:email, :password],
      ...>    add: [
      ...>        avg_rating: (fn user -> get_avg_rating(user.id)),
      ...>        reviewed: {Review, :reviewed,
      ...>              many: true,
      ...>              only: [:comment],
      ...>              add: [
      ...>                 reviewed_by: {User, :reviewer, only: [:username]}
      ...>               ]}
      ...>      ])
        %{id: 1,
          username: "joe",
          avg_rating: 10,
          reviewed: [
            %{comment: "...", reviewed_by: %{username: "mary"}},
            %{comment: "...", reviewed_by: %{username: "johnson"}}
            ]
          }


  """
  def render_schema(schema_ref, schema_map, opt \\ []) do
    cond do
      opt[@many_keyword] == true -> render_many_schema(schema_ref, schema_map, opt)
      true -> render_single_schema(schema_ref, schema_map, opt)
    end
  end


  @doc """
  Wraps a map passed in as a parameter inside of map having a data field - containing map passed in as parameter

  ## Examples

      iex> users = [
      ...>  %{id: 1, username: "joe"},
      ...>  %{id: 2, username: "mary"}
      ...> ]
      iex> render_wrapper(users)
      %{data: [
        %{id: 1, username: "joe"},
        %{id: 2, username: "mary"}
      ]}

  """
  def render_wrapper(data) do
    %{data: data}
  end

  @doc """
  Wraps the result with pagination data obtained when using :scrivener library

  ## Examples

      iex> users = [
      ...>  %{id: 1, username: "joe"},
      ...>  %{id: 2, username: "mary"}
      ...> ]
      iex> pagination_info = %Scrivener.Page{page_number: 1, page_size: 2, total_pages: 5, entries: ...}
      iex> render_paginated_wrapper(users, pagination_info, except: [:total_entries])
      %{data: [
            %{id: 1, username: "joe"},
            %{id: 2, username: "mary"}
          ],
        page_number: 1,
        page_size: 2,
        total_pages: 5}

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


#  Function takes care of converting data from current level and all nested levels
#  into maps that can be send from server.
#  This is where the magic happens!
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
          {key, custom_func} when is_function(custom_func) ->
            concatenate_options(accumulated_options, [{@adding_keyword, [{key, custom_func.(schema_map)}]}])

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


#  Function takes care of rendering a map based on options passed
#  Doesn't handle rendering on nested fields
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



#  Functions handle adding fields which get passed in opt parameter.
#  It doesn't convert values and doesn't handle adding for nested fields
  defp handle_adding_fields(map, {key, value}),
       do: map |> Map.put(key, value)

  defp handle_adding_fields(map, list_of_key_values) when is_list(list_of_key_values),
       do: list_of_key_values |> Enum.reduce(map, fn key_value_pair, acc -> handle_adding_fields(acc, key_value_pair) end)

  defp handle_adding_fields(map, _), do: map


  defp handle_timestamps(map, true), do: map

  defp handle_timestamps(map, false), do: map |> Map.drop(@timestamp_fields)

  defp handle_timestamps(map, _), do: handle_timestamps(map, false)

end
