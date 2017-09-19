## Regup

A sidekick container for Kubernetes that runs in the same pod as your application allowing you to register your app in consul with either the pod or host address, as well as provide a healthcheck and automatic deregistration. See [examples/nginx.yaml](https://github.com/spunon/regup/blob/master/examples/nginx.yaml) for a simple manifest that will demonstrate how to register an app with an HTTP health check.

Currently only one port and healthcheck is supported per *Regup* container, however you can run multiple *Regup* containers in the same pod for multiple ports and healthchecks.