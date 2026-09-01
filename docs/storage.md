# Almacenamiento

Los dos Samsung 980 PRO de 2 TB del PC de escritorio. Roles separados y montaje fijo por
`/etc/fstab`; antes se montaban por udisks bajo `/run/media/savaf/` y tenían la misma data
duplicada en ambos, así que ninguna ruta era estable entre arranques.

Nada de esto se gestiona por stow: `/etc/fstab` es del sistema y el contenido de los discos
no se versiona. Este documento es la referencia para reconstruirlo tras una reinstalación.

## Esquema

| Etiqueta | UUID | Punto de montaje | Symlink | Contenido |
|---|---|---|---|---|
| `Games` | `48ea0561-f38a-4966-a708-6d60f14e796b` | `/mnt/games` | `~/Games` | la raíz **es** la librería de Steam (`steamapps/`, `libraryfolder.vdf`), más `Standalone/` y `epic-games-store/` |
| `LIBRARY` | `efe510d5-526e-46b3-bfa0-ac3db9570994` | `/mnt/library` | `~/Library` | `Movies/`, `Comics/`, `Books/`, `Manga/`, `Archive/` y el `docker-compose.yml` de Kavita |

Ambos son ext4, propiedad de `savaf:savaf` con permisos `700`.

## Líneas de fstab

```
UUID=48ea0561-f38a-4966-a708-6d60f14e796b	/mnt/games	ext4	defaults,noatime,nofail,x-systemd.device-timeout=10	0 2
UUID=efe510d5-526e-46b3-bfa0-ac3db9570994	/mnt/library	ext4	defaults,noatime,nofail,x-systemd.device-timeout=10	0 2
```

`nofail` y `x-systemd.device-timeout=10` evitan que un disco ausente bloquee el arranque.

## Reconstruir tras una reinstalación

```sh
# 1. Confirmar que los UUID siguen siendo los de arriba
lsblk -o NAME,SIZE,FSTYPE,UUID,LABEL

# 2. Crear los puntos de montaje y añadir las dos líneas a /etc/fstab
sudo mkdir -p /mnt/games /mnt/library
sudo systemctl daemon-reload && sudo mount -a

# 3. Devolver la propiedad al usuario
sudo chown savaf:savaf /mnt/games /mnt/library

# 4. Symlinks de conveniencia
ln -s /mnt/games   ~/Games
ln -s /mnt/library ~/Library
```

En Steam, añadir `/mnt/games` como carpeta de librería: la raíz del disco ya es la librería,
no crear un subdirectorio.

## Kavita

`/mnt/library/docker-compose.yml` levanta [Kavita](https://www.kavitareader.com/) en el
puerto `5000`, montando `Manga/`, `Books/` y `Comics/` en modo lectura de la app. La config
del contenedor vive en `./kavita/config`, junto al compose.

```sh
cd /mnt/library && docker compose up -d
```
