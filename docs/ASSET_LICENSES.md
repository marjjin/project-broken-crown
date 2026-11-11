# Licencias de recursos externos

Este archivo registra **cada recurso de terceros** incluido en el proyecto. Agregar uno nuevo sin registrarlo aquí no está permitido.

## Resumen

| Origen | Licencia | ¿Uso comercial? | ¿Redistribución en el juego? | ¿Atribución obligatoria? |
|---|---|---|---|---|
| [Poly Haven](https://polyhaven.com) | [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/) | Sí | Sí | No (se agradece) |

**Verificación de la licencia (2026-11-10):**
- La página oficial <https://polyhaven.com/license> declara que **todos** los recursos se publican bajo **CC0** y que pueden usarse para cualquier fin, incluido el trabajo comercial, sin atribución.
- La API oficial (`api.polyhaven.com/info/<id>`) confirmó el nombre y los autores de cada recurso.

También se verificó la licencia de **ambientCG** (CC0, <https://docs.ambientcg.com/license/>), pero finalmente no se incorporó ningún recurso de ahí.

**Kenney** (<https://kenney.nl>) se descartó por dos motivos:
- su sitio rechaza las descargas automatizadas (HTTP 403),
- su estilo low-poly de colores no es coherente con las texturas PBR realistas del resto del juego.

**No se usan recursos extraídos de videojuegos comerciales.**

## Recursos incorporados

Todos se descargaron el **2026-11-10**, en resolución **1K** (texturas JPG de 1024 px; modelos en glTF 2.0), a `assets/third_party/polyhaven/`. Se pueden volver a descargar con `bash tools/fetch_polyhaven_assets.sh`.

### Texturas PBR

| Recurso | Autor | URL | Licencia | Archivos | Uso en el juego |
|---|---|---|---|---|---|
| Castle Wall Slates | Rob Tuytel | https://polyhaven.com/a/castle_wall_slates | CC0 | `textures/castle_wall_slates/castle_wall_slates_{diff,nor_gl,rough,ao}_1k.jpg` | Paredes, pilares y jambas (`resources/materials/crypt_wall.tres`) |
| Rock Tile Floor | Charlotte Baglioni | https://polyhaven.com/a/rock_tile_floor | CC0 | `textures/rock_tile_floor/rock_tile_floor_{diff,nor_gl,rough,ao}_1k.jpg` | Pisos, rampa y terraza (`crypt_floor.tres`) |
| Rock Wall 08 | Amal Kumar | https://polyhaven.com/a/rock_wall_08 | CC0 | `textures/rock_wall_08/rock_wall_08_{diff,nor_gl,rough,ao}_1k.jpg` | Techos (`crypt_ceiling.tres`) |

### Modelos 3D

| Recurso | Autor | URL | Licencia | Polígonos | Archivos | Uso en el juego |
|---|---|---|---|---|---|---|
| Large Castle Door | Tina | https://polyhaven.com/a/large_castle_door | CC0 | 12 640 | `models/large_castle_door/` (`.gltf`, `.bin`, `textures/*_1k.jpg`) | Puertas dobles (`scenes/interaction/crypt_door.tscn`) |
| Large Iron Gate | Josh Dean | https://polyhaven.com/a/large_iron_gate | CC0 | 38 140 | `models/large_iron_gate/` | Reja del osario (`scenes/interaction/ossuary_gate.tscn`) |
| Stone Fire Pit | Sebastian Platen | https://polyhaven.com/a/stone_fire_pit | CC0 | 3 887 | `models/stone_fire_pit/` | Braseros de la Cámara del Guardián (`scenes/props/brazier.tscn`) |
| Kite Shield | Ulan Cabanilla | https://polyhaven.com/a/kite_shield | CC0 | 10 306 | `models/kite_shield/` | Restos de la Guardia Real (`scenes/props/guard_remains.tscn`) |
| Antique Estoc | Ulan Cabanilla (modelado), James Ray Cock (texturas) | https://polyhaven.com/a/antique_estoc | CC0 | 8 246 | `models/antique_estoc/` | Restos de la Guardia Real (`guard_remains.tscn`) |
| Rock 07 | Jenelle van Heerden | https://polyhaven.com/a/rock_07 | CC0 | 14 844 | `models/rock_07/` | Montones de escombros (`scenes/props/rubble_pile.tscn`) |

Las rutas de archivos son relativas a `assets/third_party/polyhaven/`.

### Descartados

| Recurso | Motivo |
|---|---|
| Wooden Candlestick | La API declara 3 328 polígonos, pero al importarlo tenía **212 992 triángulos** para un objeto de 22 cm. Se borró. |
| Boulder 01, Rock Moss Set 01/02, Treasure Chest | Entre 57k y 124k polígonos: demasiado pesados para decoración. |

## Créditos sugeridos

CC0 no exige atribución, pero conviene reconocer el trabajo. Texto listo para usar en los créditos del juego:

> Texturas y modelos 3D de **Poly Haven** (polyhaven.com), bajo licencia CC0. Autores: Rob Tuytel, Charlotte Baglioni, Amal Kumar, Tina, Josh Dean, Sebastian Platen, Ulan Cabanilla, James Ray Cock y Jenelle van Heerden.

## Recursos propios

Todo lo demás es original de este proyecto: la geometría generada (`CryptRoom`, `BoxObstacle`), los materiales procedurales de estatua, llama, madera y hierro, el shader de grilla, las antorchas, las casas de la vista exterior y los personajes provisionales.

---

## Mixamo (Adobe): protagonista y animaciones

| Campo | Valor |
|---|---|
| Origen | <https://www.mixamo.com> (Adobe). Requiere una cuenta de Adobe gratuita. Descarga manual del usuario |
| Fecha de descarga | 2026-11-10 |
| Personaje | **Paladin J Nordstrom** → `paladin.fbx` |
| Animaciones | `idle`, `walk`, `walk_back`, `run`, `strafe_left`, `slash_1`, `slash_2`, `slash_3`, `heavy_attack`, `roll`, `hit`, `death`, `jump` (`.fbx`, FBX Binary, 30 FPS, sin reducción de keyframes) |
| Carpeta local | `assets/third_party/mixamo/raw/`, **excluida de git** |
| Licencia | Términos de Adobe para Mixamo. **No es CC0** |

**Lo que se pudo verificar (2026-11-10):**
- La FAQ oficial (<https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html>) **no se pudo leer**: el servidor devolvió HTTP 403 a las descargas automatizadas.
- Se leyó la FAQ de licencias publicada en el foro oficial de Adobe (<https://community.adobe.com/t5/mixamo-discussions/mixamo-faq-licensing-royalties-ownership-eula-and-tos/td-p/13234775>), escrita por un miembro de la comunidad en 2022. Dice, textualmente:
  - Uso: *"available for free, with no licensing or royalty fees, for unlimited commercial or non commercial use"* y *"There are no limitations on the types of paid or nonpaid projects you can use as long as it follows the distribution rules"*.
  - Atribución: *"are not required to give credit to Adobe, Mixamo, or Fuse in any way"*.
  - Restricción: *"really the only thing you can't do is distribute the raw character and animation files"*, y *"You may not distribute the files to customers or non-team members"*. Colaborar dentro del equipo sí está permitido.
  - Tampoco pueden usarse para entrenar modelos de aprendizaje automático.

**Consecuencias para este proyecto:**
1. **Los FBX originales no se suben al repositorio** (`.gitignore`), porque un repositorio público equivale a distribuirlos a personas ajenas al equipo.
2. Dentro del juego compilado (`.exe` / `.pck`) sí pueden ir, integrados como parte del juego.
3. **Antes de publicar en Steam hay que confirmar los términos vigentes** en la FAQ oficial de Adobe o en sus Términos de Uso. La fuente que se pudo leer no es oficial y puede estar desactualizada.

**Cómo restaurar los archivos en otra máquina:** iniciá sesión en Mixamo, elegí *Paladin J Nordstrom* y descargá cada animación de la tabla con el mismo nombre de archivo (FBX Binary, 30 FPS). Guardalas en `assets/third_party/mixamo/raw/`. Las escenas del juego que dependan de estos archivos van a fallar al cargar si faltan.

**Pendiente:** falta `strafe_right.fbx` (Sword And Shield Strafe hacia la derecha, *In Place*).
