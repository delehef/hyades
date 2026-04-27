{ pkgs, lib, config, inputs, ... }:

{
  cachix.enable = false;

  # https://devenv.sh/packages/
  packages = [ pkgs.git pkgs.nodejs pkgs.stripe-cli ];
  languages.elixir.enable = true;

  dotenv.enable = true;

  services.postgres = {
    enable = true;
    listen_addresses = "127.0.0.1";
    initialScript = ''
    CREATE USER hyades WITH PASSWORD 'hyadespwd' SUPERUSER;
    '';
  };

  git-hooks.hooks = {
    check-merge-conflicts.enable = true;
    end-of-file-fixer = {
      enable = true;
      files = "^(?!test/support/fixtures/gpt2/(config|tokenizer)\\.json$).*";
    };
    mix-format.enable = true;
    mixed-line-endings.enable = true;
    ripsecrets.enable = true;
    trim-trailing-whitespace.enable = true;
    typos = {
      enable = true;
      settings = {
        write = true;
        configPath = "typos.toml";
      };
    };
  };
}
