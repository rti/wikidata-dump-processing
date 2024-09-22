# Wikidata Dump Processing

A set of prototype tools to generate text embeddings for all of wikidata.

In a nix shell, the following commands are available:

```
provision               - rent servers from hetzner
bootstrap               - install nixos and deploy configuration
deploy                  - redeploy configuration
shell-workers           - ssh into worker machines using tmux
shell-scheduler         - ssh into scheduler machine
run-in-docker           - build and run in a local docker container
docker-build-and-push   - build image and push to dockerhub
```
