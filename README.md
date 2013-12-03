# Paste #

Paste is a simple [Pastie.org](http://pastie.org)-like web application based on RethinkDB. Forked from the RethinkDB Example app. Without embellishment and with added security, aimed for internal use.

# Complete stack #

*   [Sinatra](http://www.sinatrarb.com/)
*   [RethinkDB](http://www.rethinkdb.com)

# Installation #

Ensure you have RethinkDB running somewhere with ports appropriately opened. If you don't have RethinkDB installed, you can follow [these instructions to get it up and running](http://www.rethinkdb.com/docs/install/).

Pull down the code and install the necesessary gems:

```
git clone git://github.com/asheavenue/paste.git
gem install sinatra
gem install rethinkdb
```

Create a .env file:

```
cp dotenv.example .env
```

# Running the application #

```
bundle exec rackup
```

# Credits #

* This app was based on RethinkDB's Ruby sample app: https://github.com/rethinkdb/rethinkdb-example-sinatra-pastie
* That sample app was inspired by Nick Plante's [toopaste](https://github.com/zapnap/toopaste) project.
* The snippets of code used for syntax highlighting are from Ryan Tomayko's [rocco.rb](https://github.com/rtomayko/rocco) project.
* Code highlighting in snippets is done using [Pygments](http://pygments.org) or the [Pygments web service](http://pygments.appspot.com/)
* The [Solarized dark Pygments stylesheet](https://gist.github.com/1573884) was created by Zameer Manji

# License #

© 2013 <a href="http://www.asheavenue.com">Ashe Avenue</a>. Created by <a href="http://twitter.com/timboisvert">Tim Boisvert</a>.
<br />
Paste is released under the <a href="http://opensource.org/licenses/MIT">MIT license</a>.
