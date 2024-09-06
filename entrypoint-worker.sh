#!/bin/bash

# TODO: do we need a nanny port?
python -m dask worker \
  dask-scheduler.rtti.de:8786 \
  --contact-address tcp://${PUBLIC_IPADDR}:${VAST_TCP_PORT_3001} \
  --listen-address tcp://0.0.0.0:3001
