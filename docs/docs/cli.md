Pagedraw CLI
=

Installation
-

The Pagedraw CLI requires you to have [Node](https://nodejs.org/en/) installed.

```bash
npm install -g pagedraw-cli
```

Why a CLI?
-

When developing with Pagedraw, it quickly becomes a hassle to keep hitting the "Export Code" button and copy pasting the generated code into Sublime. For that reason, we created the Pagedraw CLI, which lets you fetch the generated code straight into your filesystem.

`pagedraw pull` fetches compiled docs from Pagedraw once, while `pagedraw sync` keeps live compiling and sincyng your docs in the background while you work.

You can pass doc names or ids to either command to make it fetch only the docs that have those names/ids.

```bash
pagedraw pull doc_1 'my doc 2' 4578
```


pagedraw.json
-

For the Pagedraw CLI to work, you need a `pagedraw.json` file at the root of your code repo. A sample `pagedraw.json` file looks like this

```
{
    "app": "<my_project_id>",
    "managed_folders": ["src/pagedraw/"]
}
```

In this case, the CLI will fetch docs from project with ID `<my_project_id>` and place them in paths relative to the location of your `pagedraw.json` file.

API Auth Tokens
-
When you do `pagedraw login`, the Pagedraw CLI stores API tokens in the standard `~/.netrc` file (`$HOME\_netrc` on Windows). This practice is well-established and adopted by Heroku and other friendly folks in the industry.
