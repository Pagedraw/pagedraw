# devcenter
Learn about how you can build better frontend faster with Pagedraw


# Contributing

Our CMS is https://paper.dropbox.com/doc/Documentation-7Ke5MfaBgYVjQu0Z54Cyi, a doc in Dropbox Paper.

to pull fresh content from it:

```
pipenv run ./import.py
```

to preview locally:
```
pipenv run mkdocs serve
```

to deploy:
```
pipenv run ./deploy.sh
```

Don't forget to push to all changes to github, preferably before deploying.


# Getting set up to contribute

This project uses pipenv.  Install it if you don't already have it installed with the directions on https://docs.pipenv.org/.  On Mac, it's just

```
brew install pipenv
```

Install this project using pipenv,

```
pipenv install
```

In order to deploy, you must have `surge.sh` installed, which you can do with

```
npm install -g surge
```

or

```
sudo npm install -g surge
```

whichever works.  Then ask Jared or Gabriel to give you access by having them run

```surge --add yourname@pagedraw.io```

You will get an email inviting you to surge.sh.  After accepting the invite, you will have access to deploy.
