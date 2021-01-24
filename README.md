# matrix-setup

My Matrix setup with Synapse as homeserver, mautrix-telegram, ...

# Setup

Copy the `config.example.yaml` file to `config.yaml` and fill in all the details.  
Then run

```bash
./setup.sh
```

to set up all configs. Then run

```bash
./run.sh
```

to start all services and run

```bash
docker exec -it synapse register_new_matrix_user -a -c /data/homeserver.yaml http://localhost:8008
```

to create your user account on the homeserver.

# Run

```bash
./run.sh
```

# Update

```bash
git pull
./update.sh
```