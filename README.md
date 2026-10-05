# fan-control

Widget de barra para Omarchy que controla los ventiladores del portátil mediante **nbfc** (NoteBook FanControl): muestra la velocidad/temperatura, permite fijar una velocidad manual (0–100 %) con un deslizador y volver al modo automático.

## Requisitos

Este widget **requiere nbfc instalado y su servicio activo**. Sin él, el widget solo muestra un aviso.

En Arch/Omarchy:

```sh
# Instalar nbfc (disponible en AUR)
yay -S nbfc-linux

# Activar el servicio del sistema
sudo systemctl enable --now nbfc_service

# (Opcional) cargar un perfil para tu modelo de portátil
sudo nbfc config --set auto
```

nbfc se comunica con su servicio del sistema a través de un socket, por lo que **no hace falta sudo** para usar el widget:

- `nbfc status` → estado de los ventiladores (velocidad objetivo, modo automático, temperatura)
- `nbfc set -s N` → velocidad manual para todos los ventiladores (desactiva el control automático)
- `nbfc set -a` → control automático basado en el perfil

## Uso

Al hacer clic en el icono de la barra se abre una tarjeta con:

- Estado actual (automático/manual, temperatura y velocidad objetivo).
- Deslizador de velocidad 0–100 % (al moverlo se activa el modo manual).
- Botón para volver al modo automático.

Si `nbfc` no está instalado, el icono aparece atenuado y la tarjeta muestra las instrucciones de instalación.