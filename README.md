## Regup

A sidekick container for Kubernetes that runs in the same pod as your application allowing you to register your apps in Hashicorp Consul with either the pod *or* host address and port. Regup also provides a method for specifying healthchecks and automaticcally handles deregistration in Consul. See [examples/nginx.yaml](https://github.com/spunon/regup/blob/master/examples/nginx.yaml) for a simple manifest that will demonstrate how to register an app with HTTP/Script health checks.

Run multiple *Regup* containers in the same pod for multiple ports and healthchecks!

Go to the [Docker Container!](https://hub.docker.com/r/spunon/regup/)
