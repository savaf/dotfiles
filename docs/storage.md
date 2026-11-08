# Almacenamiento

Los dos Samsung 980 PRO de 2 TB del PC de escritorio. Roles separados y montaje fijo por
`/etc/fstab`; antes se montaban por udisks bajo `/run/media/savaf/` y tenían la misma data
duplicada en ambos, así que ninguna ruta era estable entre arranques.

Nada de esto se gestiona por stow: `/etc/fstab` es del sistema y el contenido de los discos
no se versiona. Este documento es la referencia para reconstruirlo tras una reinstalación.

> `scripts/bootstrap.sh` automatiza esto (`ensure_storage_mounts`) para el hostname
> `andrea`, si los UUID de abajo están presentes (`blkid`); idempotente, no-op en
> cualquier otro host. Los pasos de abajo son la referencia manual.

## Esquema

| Etiqueta | UUID | Punto de montaje | Symlink | Contenido |
|---|---|---|---|---|
| `GAMES` | `544bc200-7fbc-442f-a1e0-311c98117cbb` | `/mnt/games` | `~/Games` | `SteamLibrary/` (la librería de Steam), `Standalone/` y herramientas sueltas |
| `LIBRARY` | `677d4c7f-d91d-4b7f-b495-304008656f69` | `/mnt/library` | `~/Library` | vacío por ahora (pensado para `Movies/`, `Comics/`, `Books/`, `Manga/`, `Archive/` y el compose de Kavita) |

Ambos son **ext4** (`mkfs.ext4 -m 0`, sin espacio reservado para root), con la raíz de cada
montaje en propiedad de `savaf` (`chown`). Antes eran exFAT (formateados desde Windows), que
no tiene permisos ni symlinks y rompía el prefijo de Proton; no se leen desde Windows.

## Líneas de fstab

```
UUID=544bc200-7fbc-442f-a1e0-311c98117cbb	/mnt/games	ext4	defaults,noatime,nofail,x-systemd.device-timeout=10	0 2
UUID=677d4c7f-d91d-4b7f-b495-304008656f69	/mnt/library	ext4	defaults,noatime,nofail,x-systemd.device-timeout=10	0 2
```

`nofail` y `x-systemd.device-timeout=10` evitan que un disco ausente bloquee el arranque.

## Reconstruir tras una reinstalación

```sh
# 1. Confirmar que los UUID siguen siendo los de arriba
lsblk -o NAME,SIZE,FSTYPE,UUID,LABEL

# 2. Crear los puntos de montaje y añadir las dos líneas a /etc/fstab
sudo mkdir -p /mnt/games /mnt/library
sudo systemctl daemon-reload && sudo mount -a
sudo chown savaf:savaf /mnt/games /mnt/library

# 3. Symlinks de conveniencia
ln -s /mnt/games   ~/Games
ln -s /mnt/library ~/Library
```

En Steam: Ajustes → Almacenamiento → añadir unidad → `/mnt/games`. La librería existente es
`/mnt/games/SteamLibrary` (creada desde Windows); Steam debe detectarla como librería.

## Kavita

`/mnt/library/docker-compose.yml` levanta [Kavita](https://www.kavitareader.com/) en el
puerto `5000`, montando `Manga/`, `Books/` y `Comics/` en modo lectura de la app. La config
del contenedor vive en `./kavita/config`, junto al compose.

```sh
cd /mnt/library && docker compose up -d
```
