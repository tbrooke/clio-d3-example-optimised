basics-of-authentication-OPTIMISED
================

This project is based off the official GitHub Rendering Data as Graphs guide but uses Typhoeus to make asynchronous HTTP API requests so greatly speads up the page load time of the D3 graphs.

===
This is the sample project built by following the "[Basics of Authentication][basics of auth]"
guide on developer.github.com.

It consists of two different servers: one built correctly, and one built less optimally.

To run these projects, make sure you have [Bundler][bundler] installed; then type
`bundle install` on the command line.

For the "less optimal" server, type `ruby server.rb` on the command line.

For the correct server, enter `ruby advanced_server.rb` on the command line.

Both commands will run the server at `localhost:4567`.

[basics of auth]: http://developer.github.com/guides/basics-of-authentication/
[bundler]: http://gembundler.com/
