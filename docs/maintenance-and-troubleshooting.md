<!--
SPDX-FileCopyrightText: 2018 Aaron Raimist
SPDX-FileCopyrightText: 2019 - 2020 MDAD project contributors
SPDX-FileCopyrightText: 2019 - 2024 Slavi Pantaleev
SPDX-FileCopyrightText: 2019 Noah Fleischmann
SPDX-FileCopyrightText: 2020 Marcel Partap
SPDX-FileCopyrightText: 2024 - 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Maintenance and Troubleshooting

## Maintenance

### How to back up the data on your server

We haven't documented this properly yet, but the general advice is to:

- back up Postgres by making a database dump. See [Backing up PostgreSQL](maintenance-postgres.md#backing-up-postgresql)

- back up all `/matrix` files, except for `/matrix/postgres/data` (you already have a dump) and `/matrix/postgres/data-auto-upgrade-backup` (this directory may exist and contain your old data if you've [performed a major Postgres upgrade](maintenance-postgres.md#upgrading-postgresql)).

You can later restore these by:

- Restoring the `/matrix` directory and files on the new server manually
- Following the instruction described on [Installing a server into which you'll import old data](installing.md#installing-a-server-into-which-youll-import-old-data)

If your server's IP address has changed, you may need to [set up DNS](configuring-dns.md) again.

### Remove unused Docker data

You can free some disk space from Docker by removing its unused data. See [docker system prune](https://docs.docker.com/engine/reference/commandline/system_prune/) for more information.

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=run-docker-prune
```

The shortcut command with `just` program is also available: `just run-tags run-docker-prune`

### Postgres

See the dedicated [PostgreSQL maintenance](maintenance-postgres.md) documentation page.

### Synapse

See the dedicated [Synapse maintenance](maintenance-synapse.md) documentation page.

## Troubleshooting

### How to see the current status of your services

You can check the status of your services by using `systemctl status`. Example:

```sh
sudo systemctl status matrix-synapse

● matrix-synapse.service - Synapse server
     Loaded: loaded (/etc/systemd/system/matrix-synapse.service; enabled; vendor preset: enabled)
     Active: active (running) since Sun 2024-01-14 09:13:06 UTC; 1h 31min ago
```

### How to see the logs

Docker containers that the playbook configures are supervised by [systemd](https://wiki.archlinux.org/title/Systemd) and their logs are configured to go to [systemd-journald](https://wiki.archlinux.org/title/Systemd/Journal).

For example, you can find the logs of `matrix-synapse` in `systemd-journald` by logging in to the server with SSH and running the command as below:

```sh
sudo journalctl -fu matrix-synapse
```

Available service names can be seen by doing `ls /etc/systemd/system/matrix*.service` on the server. Some services also log to files in `/matrix/*/data/..`, but we're slowly moving away from that.

We just simply delegate logging to journald and it takes care of persistence and expiring old data.

#### Enable systemd/journald logs persistence

On some distros, the journald logs are just in-memory and not persisted to disk.

Consult (and feel free to adjust) your distro's journald logging configuration in `/etc/systemd/journald.conf`.

To enable persistence and put some limits on how large the journal log files can become, adjust your configuration like this:

```ini
[Journal]
RuntimeMaxUse=200M
SystemMaxUse=1G
RateLimitInterval=0
RateLimitBurst=0
Storage=persistent
```

### How to check if services work

The playbook can perform a check to ensure that you've configured things correctly and that services are running.

To perform the check, run:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=self-check
```

The shortcut command with `just` program is also available: `just run-tags self-check`

If it's all green, everything is probably running correctly.

Besides this self-check, you can also check whether your server federates with the Matrix network by using the [Federation Tester](https://federationtester.matrix.org/) against your base domain (`example.com`), not the `matrix.example.com` subdomain.

### Docker cannot find an available IPv4 address pool

If Docker reports an error like `could not find an available, non-overlapping IPv4 address pool among the defaults to assign to the network`, Docker may have run out of automatically allocatable bridge-network subnets.

This can happen on servers that run many Docker networks. Docker's built-in local address pools provide 31 automatically allocated IPv4 subnets, and the default `bridge` network commonly consumes one of them.

If Docker is managed by the playbook, see [Adjusting Docker's default address pools](configuring-playbook-docker.md#adjusting-dockers-default-address-pools) for an example that changes newly created Docker networks to `/24` subnets and greatly increases the number of possible networks. If Docker is not managed by the playbook, configure Docker manually using Docker's [`default-address-pools` documentation](https://docs.docker.com/engine/network/#default-address-pools).

This change only affects Docker networks created after the Docker daemon configuration changes. Existing Docker networks keep their current subnets until they are recreated. Changing Docker daemon options causes the playbook to restart Docker, so plan it as a disruptive maintenance-window change on an active server.

#### Recreating existing networks

Changing Docker's `default-address-pools` setting only affects networks created after the Docker daemon starts with the new configuration. Existing networks keep their old subnet until they are deleted and recreated.

The playbook recreates missing Docker networks during installation tasks, so the usual migration path is to record the playbook-managed networks, stop services, delete those networks, and rerun the playbook. This does not delete service data under `/matrix`, but it is disruptive because all affected services need to stop while their networks are recreated.

Run `just` commands from the playbook directory. Run `docker` commands on the Matrix server.

Before stopping services, record the networks currently attached to Matrix containers:

```sh
for container in $(docker ps -a --format '{{.Names}}' | grep '^matrix-'); do
  docker inspect --format '{{range $name, $_ := .NetworkSettings.Networks}}{{println $name}}{{end}}' "$container"
done | sort -u | awk '!/^(bridge|host|none)$/ { print }' | tee /tmp/mdad-networks-to-recreate.txt
```

Review `/tmp/mdad-networks-to-recreate.txt` before deleting anything. Remove any network names that are externally managed or shared with non-Matrix containers. For example, if you use `matrix_playbook_reverse_proxy_type: other-traefik-container`, the Traefik network may belong to another stack and should not be deleted as part of the Matrix playbook.

If this Docker host also runs other playbook-managed stacks, such as MASH, record and review their networks too. With MASH's default identifiers, run:

```sh
for container in $(docker ps -a --format '{{.Names}}' | grep '^mash-'); do
  docker inspect --format '{{range $name, $_ := .NetworkSettings.Networks}}{{println $name}}{{end}}' "$container"
done | sort -u | awk '!/^(bridge|host|none)$/ { print }' | tee -a /tmp/mdad-networks-to-recreate.txt

sort -u -o /tmp/mdad-networks-to-recreate.txt /tmp/mdad-networks-to-recreate.txt
```

Stop every stack that uses networks you plan to delete. If you recorded MASH networks, also run `just stop-all` from the MASH playbook directory before deleting networks.

Stop Matrix services:

```sh
just stop-all
```

Delete the reviewed networks on the Matrix server:

```sh
while IFS= read -r network; do
  [ -n "$network" ] && docker network rm "$network"
done < /tmp/mdad-networks-to-recreate.txt
```

If Docker refuses to remove a network because endpoints are still attached, inspect it before retrying:

```sh
docker network inspect NETWORK_NAME --format '{{json .Containers}}'
```

After the old networks are removed, rerun the playbook. If Docker is managed by this playbook, this applies the new Docker daemon configuration, recreates missing networks, and starts services:

```sh
just install-all
```

If you recorded MASH networks, also run `just install-all` from the MASH playbook directory. On a shared MDAD/MASH host, only one playbook should manage Docker daemon configuration; if MASH is the playbook that manages Docker, run the MASH install first so it applies the Docker daemon configuration, then run the MDAD install so missing MDAD networks are recreated.

If Docker is not managed by any playbook, configure Docker's `default-address-pools` manually, restart Docker yourself, and then run `just install-all` so the playbook recreates missing networks and starts services.

You can verify the recreated subnets with:

```sh
while IFS= read -r network; do
  [ -n "$network" ] && docker network inspect "$network" --format '{{.Name}}: {{range .IPAM.Config}}{{.Subnet}} {{end}}'
done < /tmp/mdad-networks-to-recreate.txt
```

### How to debug or force SSL certificate renewal

SSL certificates are managed automatically by the [Traefik](https://doc.traefik.io/traefik/) reverse-proxy server.

If you're having trouble with SSL certificate renewal, check the Traefik logs (`journalctl -fu matrix-traefik`).

If you're [using your own webserver](configuring-playbook-own-webserver.md) instead of the integrated one (Traefik), you should investigate in another way.
