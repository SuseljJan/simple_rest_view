# SimpleRestView

###Description:
SimpleRestView is a library to help you shorten the amount of code needed to write your views in Phoenix framework when  generating json data for a REST service. 

####Functions:
#####render_schema()

**input parameters:**\
1 - Reference to a schema containing all the fields you wish to render<br>
2 - Result from a query <br>
3 - Options (optional): <br>
- only - fields specified in only will be the only fields of schema to get rendered
- except - fields specified in except will be excluded from rendering. All other fields on schema will be rendered
- many - a boolean which determines if values passed in second parameter should be rendered as a single map or a list of maps, defaults to false (single map)
- include_timestamps - a boolean which determines whether to include timestamp fields (inserted_at, updated_at) in the rendered map, defaults to false
- add - enables adding fields. Can be specified in a format [field_name: {SchemaReference, :field_which_references_nested_schema, [options...]}] (options can contain other nested fields) or as [field_name: (fn model -> end)]

**Example**

With result from query:
```elixir
%User{
id: 1,
username: "usr1",
reviewed: [
  %Review{...},
  %Review{...}
],
...}
```
With the following function call:
```elixir
SimpleRestView.render_schema(User, user, only: [:id, :username], 
                              add: [
                                 avg_rating: (fn user -> calc_avg_rating(user.id) end),
                                 reviewed: {Review, :reviewed, many: true}                     
                                ]                                 
                            )
```
Result would be: 
```elixir
%{id: 1,
  username: "usr1",  
  reviewed: [{...}, {...}],
  avg_rating: ...}
```

<br><br>
**usage:** 

```elixir
alias MyApp.SimpleRestView, as: SimpleRV

    def render(..., %{user, user}) do
      User
      |> SimpleRV.render_schema(user)
    end
```
is equivalent to
```elixir
    def render(..., %{user, user}) do
      %{id: user.id,
        username: user.username,
        email: user.email,
        ...}  
    end
```

<br><br><br>

```elixir
    def render(..., %{user, user}) do
      User
      |> SimpleRV.render_schema(user, only: [:id, :username],
           add: [
              reviewed: {Review, :reviewed, many: true},
              custom_field: (fn review -> some_function(review.id) end)
               ])
    end
```
is equivalent to
```elixir
    def render(..., %{user, user}) do
      %{id: user.id,
        username: user.username
        reviewed: render_many(user.reviewed, ReviewView, "review.json")}
    end

...
defmodule MyApp.ReviewView do
  ...
  
    def render("review.json", %{review: review}) do
      %{id: review.id,
        comment: review.comment,
        ...
        custom_field: some_function(review.id)}   
    end
end
```




#####render_wrapper()
```elixir
alias MyApp.SimpleRestView, as: SimpleRV

    def render(..., %{user, user}) do
      User
      |> SimpleRV.render_schema(user)
      |> SimpleRV.render_wrapper()
    end
```
is equivalent to
```elixir

    def render(..., %{user: user}) do
      %{data: render_one(user, UserView, "user.json")}
    end

    def render("user.json", %{user, user}) do
      %{id: user.id,
        username: user.username,
        email: user.email,
        ...}  
    end
```

#####render_paginated_wrapper()

```elixir
    def render(..., %{users, users}) do
      User
      |> SimpleRV.render_schema(users.entries, only: [:id, :username], many: true,
           add: [
              reviewed: {Review, :reviewed, many: true},
              custom_field: (fn review -> some_function(review.id) end)
               ])
      |> SimpleRV.render_paginated_wrapper(user)
    end
```
is equivalent to
```elixir
    def render(..., %{users, users}) do
      %{data: render_many(users.entries, UserView, "user.json"),
        page_number: users.page_number,
        page_size: users.page_size,
        total_entries: users.total_entries,
        total_pages: users.total_pages}   
    end    

    def render("user.json", %{user, user}) do
      %{id: user.id,
        username: user.username
        reviewed: render_many(user.reviewed, ReviewView, "review.json")}
    end

...
defmodule MyApp.ReviewView do
  ...
  
    def render("review.json", %{review: review}) do
      %{id: review.id,
        comment: review.comment,
        ...
        custom_field: some_function(review.id)}   
    end
end
```




## Installation

The package can be installed
by adding `simple_rest_view` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:simple_rest_view, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/simple_rest_view](https://hexdocs.pm/simple_rest_view).

