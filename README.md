# [Hyades](https://hyades.info)

Hyades is developed on the
[OTP](https://erlang.org/doc/design_principles/users_guide.html) with
[Elixir](https://elixir-lang.org/) using the [Phoenix
framework](https://www.phoenixframework.org/). All dependencies are listed in
the [Mix file](mix.exs).

To start hacking on your own Hyades instance:

  * Configure your database secrets in `config/dev.exs`
  * Setup the project with `mix setup`
  * Install the JS buils pipeline with `npm install --prefix ./assets`
  * Install Tailwind CSS with `mix tailwind.install` then `mix tailwind default`
  * Start Phoenix endpoint with `mix phx.server`

You can now visit [`localhost:4000`](http://localhost:4000) from your browser.

## Self Hosting

### Create a Github App

You must first [create a Github
app](https://developer.github.com/apps/building-github-apps/creating-a-github-app/),
which will give you a token to give access to the Github API to your deployment
of Hyades, with the callback URL set to `https://YOURDOMAIN.FQDN/ROOT/auth/github/callback`.
Once done, fill the required data (app ID and token) in `config/{dev,prod}.exs`.

## License

Hyades is developed & distributed under the [CeCILL-C](https://en.wikipedia.org/wiki/CeCILL) license (LGPL-compatible).
