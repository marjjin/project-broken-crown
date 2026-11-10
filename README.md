# Project Broken Crown

RPG de acción 3D en tercera persona, ambientado en un mundo medieval de fantasía oscura.

**Fase actual: 1 — Prototipo de movimiento y cámara.** Todavía no hay combate, enemigos, inventario ni persistencia.

---

## Requisitos

| Requisito | Detalle |
|---|---|
| Motor | **Godot 4.7.2 stable**, edición estándar (GDScript, *no* la edición .NET/C#) |
| Versión mínima esperada | Godot 4.4 (el código usa API estable desde 4.3; no se probó en versiones anteriores) |
| Plantillas de exportación | Solo para exportar a web: *Editor → Manage Export Templates → Download and Install* |
| Plugins externos | Ninguno |
| Servidor local (prueba web) | Cualquier servidor HTTP estático, por ejemplo Python 3 (`python -m http.server`) |

Descarga oficial de Godot: <https://godotengine.org/download>

## Abrir y ejecutar

1. Abrí Godot y en el Project Manager elegí **Import** → seleccioná el archivo `project.godot` de esta carpeta.
2. La primera apertura reimporta los recursos (se crea la carpeta `.godot/`, que no se versiona).
3. Presioná **F5** (Run Project). La escena principal es `res://scenes/main/main.tscn`.

Desde la línea de comandos:

```bash
godot --path . # abre el juego directamente
godot --path . -e # abre el editor
```

## Controles

| Acción | Teclado / Mouse | Gamepad |
|---|---|---|
| Moverse | W A S D | Stick izquierdo |
| Cámara | Mouse (con el cursor capturado) | Stick derecho |
| Correr | Shift (mantener) | L3 (clic del stick izquierdo) |
| Saltar | Espacio | A / Cruz |
| Liberar el mouse | Esc | — |
| Capturar el mouse | Clic izquierdo | — |

Las teclas usan *physical keycodes*: WASD queda en la misma posición física con distribuciones AZERTY/QWERTZ.

El salto se desactiva sin tocar código: abrí `resources/player/default_movement_settings.tres` y desmarcá **Jump Enabled**.

## Estructura

```
project.godot                 Configuración (renderizador Compatibility, capas físicas, autoload)
export_presets.cfg            Preset de exportación Web (sin threads)
scenes/
  main/main.tscn              Nivel de prueba: suelo, luz, paredes, rampa, escalones, pilares, túnel
  player/player.tscn          Personaje (CharacterBody3D + cápsula + CameraRig instanciado)
  camera/camera_rig.tscn      Rig de cámara: Yaw → PitchPivot → SpringArm3D → Camera3D
  level/box_obstacle.tscn     Caja estática reutilizable
  ui/hud.tscn                 HUD mínimo (controles + estado)
scripts/
  core/input_actions.gd       Nombres de acciones como constantes (evita strings repetidos)
  core/input_bindings.gd      Autoload: registra los bindings de teclado y gamepad por defecto
  core/mouse_capture_controller.gd  Captura/liberación del cursor
  player/player_controller.gd Locomoción: gravedad, aceleración, carrera, salto, giro suave
  player/movement_settings.gd Resource con todos los parámetros ajustables
  camera/third_person_camera.gd  Rotación de cámara (mouse y stick) con límites de pitch
  level/box_obstacle.gd       Genera malla + colisión a partir de un único `size`
  ui/hud.gd                   Actualiza el HUD 4 veces por segundo
resources/
  player/default_movement_settings.tres
  materials/grid_ground.tres
assets/shaders/grid_ground.gdshader  Grilla procedural del suelo (sin texturas)
```

### Decisiones de diseño

- **Jugador y cámara desacoplados.** `PlayerController` solo conoce un `Node3D` cuya orientación define "adelante" (`orientation_reference`). No sabe que es una cámara. La cámara no sabe nada del jugador.
- **El cuerpo del jugador no rota.** Solo gira el nodo `Visual`. Así el rig de cámara puede ser hijo del jugador (hereda la posición, no la orientación) y la cápsula de colisión es estable.
- **La cámara no atraviesa paredes** porque `SpringArm3D` lanza una esfera (radio 0,25 m) contra la capa física `world`. El jugador está en la capa `player`, así que el brazo nunca choca con su propio personaje.
- **Parámetros en un Resource** (`MovementSettings`). Se pueden crear variantes (por ejemplo, para otros personajes) sin tocar código.
- **Bindings en código, no en `project.godot`.** Son legibles, fáciles de comparar en el control de versiones y van a servir de base para un menú de reasignación. Si una acción ya está definida en *Project Settings → Input Map*, el autoload la respeta y no la pisa.
- **`BoxObstacle`** (`@tool`) mantiene sincronizadas la malla y la colisión. Sus nodos hijos son internos: no se guardan en la escena ni se duplican al copiar el nodo.

### Capas físicas

| Capa | Nombre | Uso |
|---|---|---|
| 1 | `world` | Escenario estático; la máscara del SpringArm3D |
| 2 | `player` | Cápsula del jugador |

## Compatibilidad web

- El renderizador es **Compatibility** (OpenGL ES 3 / WebGL 2) en todas las plataformas.
- No se usan texturas. Las sombras son direccionales ortogonales con un atlas de 2048 px. No hay SSAO, SSR, SDFGI, glow ni efectos que solo existen en Forward+.
- El preset Web tiene **thread support desactivado**, así que no requiere los headers `COOP/COEP` (`SharedArrayBuffer`). Funciona en hosts estáticos simples como itch.io o GitHub Pages.
- En web el cursor **no** se captura al iniciar, porque los navegadores solo permiten *pointer lock* después de un gesto del usuario. El HUD pide un clic.

## Exportación para Windows (verificada)

1. Instalá la plantilla **Windows x86_64**: *Editor → Administrar Plantillas de Exportación* → *Conectarse* → elegí un mirror → marcá *Windows x86_64* → instalar.
2. *Proyecto → Exportar…* → preset **Windows Desktop** (ya incluido, con PCK embebido) → **Exportar Proyecto** → `build/windows/BrokenCrown.exe`.
3. Ejecutá `BrokenCrown.exe`. Si exportaste con depuración, también se genera `BrokenCrown.console.exe`, que abre una consola con los errores.

Windows SmartScreen puede advertir porque el ejecutable no está firmado ("Más información → Ejecutar de todas formas").

## Prueba de exportación web

1. Instalá las plantillas de exportación: *Editor → Manage Export Templates → Download and Install*.
2. *Project → Export…* → seleccioná el preset **Web** (ya incluido) → **Export Project** → guardá en `build/web/index.html`. Si la carpeta `build/web` no existe, creala antes.
3. Serví la carpeta por HTTP. Abrir `index.html` con doble clic **no** funciona, porque `file://` bloquea la carga del `.wasm`/`.pck`:
   ```bash
   python -m http.server 8000 --directory build/web
   ```
   Alternativa: en el editor, el botón **Remote Deploy / Run in Browser** (ícono de HTML5 arriba a la derecha) levanta un servidor local automáticamente.
4. Abrí `http://localhost:8000` en Chrome y en Firefox, y verificá:
   - [ ] La escena carga y se ve el HUD con `Plataforma: Web` y `Render: gl_compatibility`.
   - [ ] Clic → el cursor se captura y el mouse rota la cámara.
   - [ ] Esc → el cursor se libera (el navegador también muestra su aviso).
   - [ ] WASD, Shift y Espacio funcionan.
   - [ ] Las sombras se ven y los FPS se mantienen estables.
   - [ ] La consola del navegador (F12) no muestra errores en rojo.

## Checklist de aceptación (en el editor)

- [ ] F5 inicia sin errores en el panel *Output* / *Debugger*.
- [ ] W/A/S/D mueven al personaje relativo a la cámara.
- [ ] El mouse gira la cámara. El pitch está limitado (no da la vuelta).
- [ ] Shift aumenta la velocidad (el HUD muestra `Corriendo: si`).
- [ ] Espacio salta. Los escalones al oeste (`JumpSteps`) requieren saltar.
- [ ] Al soltar las teclas, el personaje desacelera en lugar de frenar en seco.
- [ ] El personaje gira suavemente hacia la dirección de movimiento.
- [ ] Choca y se desliza contra paredes, pilares, cajas y el muro en ángulo.
- [ ] Sube la rampa (al este) hasta la plataforma.
- [ ] Al acercar la cámara a un pilar o entrar al túnel (sudoeste), la cámara se acorta y no atraviesa la geometría.
- [ ] Esc libera el cursor y un clic lo recaptura.
- [ ] Con un gamepad conectado, los sticks mueven al personaje y la cámara.

## Limitaciones conocidas

- **Validación de esta fase:** probada en Godot 4.7.2, tanto en el editor como en el build de Windows (AMD Radeon RX 6600, Compatibility). La exportación web **no está verificada** hasta completar la prueba de arriba.
- **Micro-stutter en monitores de más de 60 Hz:** el personaje se mueve en `_physics_process` (60 Hz) y no está activada la interpolación física. Esto se va a resolver en una fase posterior, cuando se defina el sistema de cámara definitivo.
- **Sin escalones automáticos:** `CharacterBody3D` no sube escalones por sí solo. Los desniveles de más de unos 10 cm requieren saltar (es intencional en el nivel de prueba).
- **Gamepad:** el mapeo usa la convención SDL (A = botón inferior). Los mandos no reconocidos pueden tener los ejes cambiados.
- **Proyecto dentro de OneDrive:** la sincronización puede bloquear archivos de `.godot/` durante la importación y provocar errores intermitentes. Se recomienda pausar OneDrive mientras trabajás, o mover el proyecto fuera de la carpeta sincronizada.
- **Escape en navegador:** el navegador intercepta Esc para salir del pointer lock. El efecto es el mismo (se libera el cursor), pero el evento puede no llegar al juego.
