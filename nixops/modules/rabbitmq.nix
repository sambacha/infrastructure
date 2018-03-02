{ config, lib, ... }:
let
  cfg = config.services.ofborg.rabbitmq;
in {
  options = {
    services.ofborg.rabbitmq = {
      enable = lib.mkEnableOption {
      };

      cookie = lib.mkOption {
        type = lib.types.string;
      };

      domain = lib.mkOption {
        type = lib.types.string;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    security.acme.certs."${cfg.domain}" = {
      plugins = [ "cert.pem" "fullchain.pem" "full.pem" "key.pem" "account_key.json" ];
      group = "rabbitmq";
      allowKeysForGroup = true;
    };

    services.nginx = {
      enable = true;
      virtualHosts."${cfg.domain}" = {
        enableACME = true;
        forceSSL = true;
      };
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];

    # Use FQDNs for resolving peers
    systemd.services.rabbitmq.environment.RABBITMQ_USE_LONGNAME = "true";

    services.rabbitmq = {
      enable = true;
      cookie = lib.escapeShellArg cfg.cookie;
      plugins = [ "rabbitmq_management" "rabbitmq_web_stomp" ];
      config = let
          cert_dir = "${config.security.acme.directory}/${cfg.domain}";
        in ''
           [
             {rabbit, [
                {tcp_listen_options, [
                        {keepalive, true}]},
                {heartbeat, 10},
                {ssl_listeners, [{"::", 5671}]},
                {ssl_options, [
                               {cacertfile,"${cert_dir}/fullchain.pem"},
                               {certfile,"${cert_dir}/cert.pem"},
                               {keyfile,"${cert_dir}/key.pem"},
                               {verify,verify_none},
                               {fail_if_no_peer_cert,false}]},
                {log_levels, [{connection, debug}]}
              ]},
              {rabbitmq_management, [{listener, [{port, 15672}]}]},
              {rabbitmq_web_stomp,
                       [{ssl_config, [{port,       15671},
                        {backlog,    1024},
                        {cacertfile,"${cert_dir}/fullchain.pem"},
                        {certfile,"${cert_dir}/cert.pem"},
                        {keyfile,"${cert_dir}/key.pem"}
                   ]}]}
           ].
         '';
     };
  };
}
