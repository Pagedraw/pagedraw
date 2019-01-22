'use babel';

import { CompositeDisposable, File } from 'atom';
import path from 'path';

class PdAtomView {

  constructor(uri) {
    this.uri = uri;
    this.file = new File(this.uri);

    // Create root element
    this.element = document.createElement('webview');
    this.element.partition = "pagedraw";
    // let protocol = this.element.getWebContents().session.protocol;
    // protocol.registerStandardSchemes(['pdcore'], {secure: true});
    // protocol.registerFileProtocol('pdcore', (request, callback) => {
    //   console.log("ok, we're in");
    //   const url = request.url.substr(9);
    //   callback({path: path.normalize(`/Users/jared/Desktop/do-the-lala/do-the-lala/${url}`)});
    // }, (error) => {
    //   if (error) {
    //     console.error('Failed to register protocol', error);
    //   }
    // });

    let rpc_send = (data) => {
      this.element.executeJavaScript(`
        window.__atom_rpc_recv(${JSON.stringify(data)});
      `);
    };

    let rpc_recv = (data) => {
      if (data.msg === "ready") {
        this.file.read().then((fileContents) => {
          rpc_send({msg: "load", fileContents})
        });

      } else if (data.msg == "write") {
        this.file.write(data.fileContents)

      }
    };

    this.element.addEventListener('console-message', (e) => {
      let prefix = "atomrpc:";
      if (e.message.startsWith(prefix)) {
        let data = JSON.parse(e.message.slice(prefix.length));
        rpc_recv(data);
      } else {
        console.log('Guest page logged a message:', e.message);
      }
    });

    // Passthrough all keyboard events to our webview when we're focused.
    // Without this, atom eats some interesting keypresses, like backspace and arrow keys.
    // FIXME this disables all atom keyboard shortcuts too, including useful ones.
    this.element.addEventListener('keydown', (e) => {
      e.stopPropagation()
    });

    this.element.addEventListener('keyup', (e) => {
      e.stopPropagation()
    });


    this.element.src = `file://${path.resolve(__dirname, "editor.html")}`;
  }

  // Returns an object that can be retrieved when package is activated
  serialize() {}

  // Tear down any state and detach
  destroy() {
    this.element.remove();
  }

  getElement() {
    return this.element;
  }

  getTitle() {
    return path.basename(this.uri);
  }

  getURI() {
    return this.uri;
  }

  getPath() {
    return this.uri;
  }
}

let subscriptions = null;

export default {
  activate(state) {
    subscriptions = new CompositeDisposable(
      atom.workspace.addOpener((uri) => {
        if (path.extname(uri) === '.pagedraw') {
          return new PdAtomView(uri);
        }
      })
    );
  },

  deactivate() {
    if (subscriptions) {
      subscriptions.dispose();
    }
  }
};
