next_page: /data-binding/


Installation
=
You can use Pagedraw with any IDE, text editor, version control, and development tools you like.

Follow the steps below to install the Pagedraw CLI.  The CLI syncs Pagedraw-generated code directly into your file system.  Since they're just files, they fit right in to projects where you're also using, for example, vim or git.

This guide assumes you already have a React project setup. If you don't, consider trying Pagedraw in <a target="_blank" href="https://pagedraw.io/fiddles/todo-mvc">a fiddle instead</a>.

### 1. Open Pagedraw and create a doc

<a target="_blank" href="https://pagedraw.io/apps"><button type="button" class="btn btn-success full-width">LOG IN</button></a>

Click `Import Sketch` in the dashboard and upload [this Sketch
file](https://www.dropbox.com/s/6srbc862w946aj6/button.sketch?dl=1).

You can create docs in Pagedraw without Sketch, but for now, importing a Sketch file is the quickest way to get started. Your first doc should look like this:

![](/images/installation/imported-sketch-button.png)


### 2. Install the Pagedraw CLI

    npm install -g pagedraw-cli
    pagedraw login

The [Pagedraw CLI](/cli/) lets you download Pagedraw generated code into your codebase.  Authentication will open a browser window for you to Google Auth with.

### 3. Add a pagedraw.json file

Click on the `Export Code` button in the topbar to open the modal shown in the screenshot below.  Copy the listing under `pagedraw.json` into a file called `pagedraw.json` at the root of your project.  This file tells the Pagedraw CLI which Pagedraw project to sync with.

<img class="full-width"
    alt="Project in dashboard with project named Jared\'s App"
    src="/images/installation/find-project-name.png" />

Now run

```bash
pagedraw sync
```

to download the hello world page's code into `src/pagedraw/button.js`.  Sync will keep running, continuously downloading updated code as you edit the doc in the Pagedraw Editor.

### 4. Wire the pagedrawn files into the React app

Finally, go into any of your own React components where you'd like to use that button.  Let's say your project has a `HomeApp` component.  You might do

```jsx
import React from 'react';
import PagedrawButton from '../relative/path/to/src/pagedraw/button';

class HomeApp extends React.Component {
    render() {
        return <div className="my-own-div">
            <PagedrawButton />
            <div>Other, unrelated content</div>
        </div>;
    }
}
```

where `../relative/path/to/src/pagedraw/button` is the relative path from your calling file to `src/pagedraw/button`.

If you refresh your local dev environment you should now see the Pagedraw button there. Go ahead and make any changes to that button in the Pagedraw doc (maybe change the font color, for example) and see that those changes are reflected live in your local application!
