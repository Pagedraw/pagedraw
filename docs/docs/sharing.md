# Saving and Collaboration

Pagedraw uses a mix of Google Docs-style live collaboration and Git-style commits. It automatically saves your work and shows you other users’ changes as they happen, but lets you collaboratively save checkpoints and rollback to them.

## Livecollab and Autosaving

Multiple users can safely work in the same doc at the same time.  You can see what everyone’s doing and work together remotely.  You never need to manually hit save; Pagedraw is always autosaving for you.

## Sharing

Each doc lives in a project.  Sharing is done on a per-project basis.  To share a doc with someone, share the project it’s in with them.  Otherwise, when you give them a link to the doc they won’t be able to see it.  To share a project, go to the dashboard at [https://pagedraw.io/apps/](https://pagedraw.io/apps/) and add the other person’s email to the `Collaborators` list on the left. [Read more about Docs and Projects](/docs).

## View-only mode

If you want to show someone a doc, but don’t want them to accidentally move anything, you can send them a readonly link.  A readonly link is just a link with `/readonly` at the end. For example, for the doc at https://pagedraw.io/pages/123, the readonly link would be https://pagedraw.io/pages/123/readonly.  The readonly viewer will see what you’re working on in realtime, as you make edits.

## Commits
![](https://d2mxuefqeaa7sj.cloudfront.net/s_41363B0C4E0B269D5C0E14AE67F23B3D1EBCE40C80A7D6E5DB647DAF88CFC52A_1516762855991_Screen+Shot+2018-01-23+at+7.00.37+PM.png)


Saving commits on a doc lets you experiment with the safety of knowing you can roll back to a known-good state.   If you have ever worked with code, you have probably used something like git for version control. Commits here are a similar, but simpler idea.

To see doc’s commits or make a new commit, go to the Doc Inspector sidebar.  (This is the right sidebar when no blocks are selected, in the `DRAW` tab.)

To make a new commit, describe the changes made since the last commit in the `Commit message` field and click on the `COMMIT` button.  All previous commits are listed below the `COMMIT` button.  Each commit has an author, a timestamp, a commit message, and a `RESTORE` button to rollback to that commit.

## Uncommitted Changes

If you have uncommitted changes, a yellow dot will appear in the upper right corner of the topbar.  You can see it in the screenshot above.  When you make a commit, or undo any uncommitted changes, the dot will disappear.  Clicking the dot will open the commits sidebar. The signal only shows up in docs with at least one commit, so we don’t confuse users who haven’t learned about commits yet.

## Using commits like branches

Rolling back to a commit **does not** get rid of the commits made after it.  This is really useful for flipping between two alternative designs when you’re not sure which you want.  Just make and commit each one.  Then you can use the `RESTORE` buttons to switch between the commits for each alternative.  It’s like a basic form of branching, for git users familiar with that term.

## Checking in generated code

We recommend making a commit in Pagedraw for every commit you make in git of Pagedraw-generated code.  In the future, this may be automatic.

## Shared history

You have access to all commits made by any collaborator, not just your own commits.

Commits are permanent and cannot be deleted.
