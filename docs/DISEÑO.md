# Furgón — documento de diseño

Juego de reparto de paquetes en una van. Mundo 3D isométrico + una interfaz tipo "sistema operativo"
(overlays y ventanas) desde la que se maneja casi todo. Single player o cooperativo de a 2, con el mismo sistema.

## Las 5 piezas del sistema

Todo lo demás tiene que salir de combinar estas piezas. Si una mecánica nueva pide una regla especial, primero
se intenta expresar con estas.

### 1. Mundo
- 3D isométrico, cámara ortográfica. **Siempre visible.**
- Regla: un overlay o una ventana **nunca tapa todo el mundo**, y tu personaje siempre está visible en él.
- Afuera de la van caminás haciendo clic en el suelo (estilo Sims).
- Clic en una **entidad** del mundo (personaje, NPC, rueda, objeto tirado) → abre su **ventana**.
- **Interiores que se desvanecen:** cuando hay un personaje adentro de la van (o de un edificio), el techo y las
  paredes que tapan la vista se vuelven transparentes, como al entrar a una casa en un juego isométrico.
  Así podés hacer clic en tu personaje sentado y ver los paquetes de atrás en el mundo 3D.
  Tiene que ser un sistema genérico ("interior": techo + paredes que tapan la cámara), no algo propio de la van.

### 2. Espacios → Overlay
- Un espacio es un lugar donde *está* tu personaje (ej.: la cabina de la van, con sus dos asientos).
- Tu overlay depende del espacio donde estás. Sin espacio = sin overlay.
- El overlay se **comparte**: todos los jugadores del mismo espacio ven lo mismo y ven las **manos** de los otros.
- Los overlays tienden a ser horizontales: querés seguir viendo el mundo mientras los usás.

### 3. Ventanas
- Se abren al hacer clic en una entidad. Se pueden mover, minimizar y cerrar (como en Windows).
- Muestran el retrato (3D) de la entidad y sus "ranuras" (estado, lo que te ofrece, diálogo…).
- Sirven para cosas donde no hace falta ver el mundo (ej.: minijuego de la rueda).

### 4. Ítems (pseudo-2D)
- Son 3D por fuera, pero se comportan en 2D: física sin profundidad y siempre mirando a la cámara.
- Siempre están en un **contenedor**: el tablero, la caja de atrás, la mano de un personaje (1 solo ítem) o el suelo del mundo.
- Lo que hay en los contenedores tiene consecuencias: peso atrás cambia el manejo; cosas en el tablero tapan la visión.
- Los **controles** (volante, palanca, llave, pedales, guantera) son "agarrables" anclados: se manipulan con la misma mano.

### 5. Manos y arrastrar/soltar
- Cada jugador es una mano (cursor 2D, con 1–2 poses según si agarra o no).
- **Una mano agarra una cosa a la vez, y una cosa la agarra una sola mano a la vez.**
- **Regla única de soltar:** soltás un ítem sobre un *destino*, y el destino decide si lo acepta.
  - Destinos: una superficie de overlay, una ventana (o una ranura de ella), una entidad del mundo.
  - Soltar sobre una entidad del mundo = **abrir su ventana** y seguir arrastrando ahí (como soltar un archivo sobre el ícono de la barra de tareas).
  - Si no se acepta (no entra, no corresponde), el ítem vuelve a donde estaba.
- Ejemplos que salen solos: comer (comida → tu ventana), recibir un paquete (ventana del NPC → tu ventana),
  cargar la van (tu mano → caja de atrás), mostrar documentos (guantera → ventana del policía),
  dar un ítem en un diálogo (cambia las opciones de diálogo).

## Cooperativo
- La van está pensada para que manejar rápido sea difícil para uno solo: uno al volante, otro con pedales/marchas/mapa.
- Todo el estado (controles, ítems, quién agarra qué) es **dato compartido**; las manos solo mandan intenciones
  (agarrar, mover, soltar). Así single player y multijugador usan el mismo código.

## Decisiones tomadas (provisorias)
- **Todo se maneja con el mouse.** Nada del tablero se usa con teclado (los pedales se arrastran).
  Por ahora **sin pedales**: la palanca dicta la velocidad (1ra 12, 2da 25, 3ra 40, 4ta 60, R 8 km/h)
  y en punto muerto la van frena sola hasta parar (`VanControls.gear_sets_speed`, `clutch_enabled`).
- **E = salir del espacio** (bajarse de la cabina / irse de la caja). Dentro de un espacio, hacer clic
  en el mundo no te saca; solo abre ventanas de personajes.
- **Agarrar y soltar (regla única):** agarrado = fantasma (sin física, no choca, sigue al mouse por toda
  la pantalla), verde si se puede soltar ahí y rojo si no. Al soltar: sobre una ventana que lo acepta →
  ventana; en un lugar libre → física con la velocidad del mouse; en un lugar inválido (encima de algo,
  pared, afuera) → vuelve a donde estaba. Siempre existe una sola versión de cada ítem.
- Ítems con medidas reales en metros (`ItemData.dims`); cada vista los escala (`units_per_meter`).
- Contorno amarillo al pasar el mouse por lo que se puede usar en el mundo (personajes, cabina, caja).
- Estilo: todo low poly moderado con sombreado suave (ver `game/core/lowpoly.gd`).

## Pendiente / ambiguo
- ¿La rueda, el motor: overlay o ventana? Tendencia: ventana si no hace falta ver el mundo.
- ¿Las ventanas son de cada jugador o compartidas?
- Cómo se ve el diálogo dentro de una ventana.

## Arquitectura (código)
- `Desktop` (game/ui): reparte el input del jugador local: ventanas > overlay de su espacio > mundo.
  Maneja el arrastre universal (`begin_carry` / soltar / devolver si nadie acepta).
- `Overlay` (game/overlay): escena 3D oblicua por espacio. `Grabbable` = mando agarrable; `ItemSurface` =
  superficie con ítems apilables; `ItemNode` = ítem apoyado.
- `GameWindow` / `WindowManager` (game/windows): ventanas + barra de tareas. `can_accept` / `accept_drop`.
- `Player` = mano + personaje + espacio. `Hand` sostiene un mando o arrastra un ítem, nunca dos cosas.
- `ItemData` es el dato; cada contenedor crea su propio dibujo con `make_visual()`.
- `VanControls` es el estado compartido de mandos que lee la física de la van.

## Notas técnicas
- Godot 4.5, Forward+.
- Overlay: escena 3D propia con cámara ortográfica de frente renderizada encima del mundo (SubViewport);
  la física de los ítems corre en 2D (x, y) y los modelos 3D solo copian esa posición.
- Pensar todo para red desde el principio, aunque al comienzo se juegue solo.
