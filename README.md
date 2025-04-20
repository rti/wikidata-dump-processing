# Wikidata Dump Processing

> **⚠️ This project is archived and no longer maintained.**  
> Parts of this prototype supported the development of the [Wikidata Embedding Project](https://www.wikidata.org/wiki/Wikidata:Embedding_Project).

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
