
<h1> SimpleRestView</h1>

<h3>Description:</h3>
SimpleRestView is a library to help you shorten the amount of code needed to write your views in Phoenix framework when  generating json data for a REST service. 

<h4>Functions:</h4>
<h2>render_schema()</h2>

**input parameters:**\
1 - Reference to a schema containing all the fields you wish to render<br>
2 - Result from a query <br>
3 - Options (optional): <br>
- only - fields specified in only will be the only fields of schema to get rendered
- except - fields specified in except will be excluded from rendering. All other fields on schema will be rendered
- many - a boolean which determines if values passed in second parameter should be rendered as a single map or a list of maps, defaults to false (single map)
- include_timestamps - a boolean which determines whether to include timestamp fields (inserted_at, updated_at) in the rendered map, defaults to false
- add - enables adding fields. Can be specified in a format [field_name: {SchemaReference, :field_which_references_nested_schema, [options...]}] OR [field_name: (fn model -> end)] OR [field_name: %{custom_field: custom_val, ...}]

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
passed in as second parameter to function:
```elixir
SimpleRestView.render_schema(User, user, only: [:id, :username], 
                              add: [
                                 avg_rating: (fn user -> calc_avg_rating(user.id) end),
                                 reviewed: {Review, :reviewed, many: true}                     
                                ]                                 
                            )
```
result would be: 
```elixir
%{id: 1,
  username: "usr1",  
  reviewed: [{...}, {...}],
  avg_rating: ...}
```

<br><br>
**usage:** 

Following call:
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
Following call:
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



<br><br>

<h2>render_wrapper()</h2>

**usage:** 
Following call:

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

<br><br>
<h2>render_paginated_wrapper()</h2>

**usage:** 

Following call:
```elixir
    def render(..., %{users, users}) do
      User
      |> SimpleRV.render_schema(users.entries, only: [:id, :username], many: true,
           add: [
              reviewed: {Review, :reviewed, many: true, 
	              add: [custom_field: (fn review -> some_function(review.id) end)]
	              },
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




<h2>Installation</h2>

The package can be installed
by adding `simple_rest_view` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:simple_rest_view, "~> 0.1.0"}
  ]
end
```


