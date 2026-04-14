# Cubescape

## Bugs
- Wenn man aus der Spielszene zurueck zum Menü geht, sturzt das Program ab. Dieser Fehler ist nach der Einfuehrung der `draw_grid()` Funktion aufgetreten. Hat etwas mit `Level.grid` zu tun. Es sieht so aus, als wuerde die Funktion `onUpdate()` von der alte Szene noch laufen, was den Fehler erklaeren wuerde, da die Funktion `onCleanup()` bereits ausgefuehrt wurde und `Level.grid` aus Heap geloescht wurde.  

## Allgemein
-  







## Vergriffen
### Marius
- Engine
    - Spielfeld
    - Level-Editor




### Freddi
- Menü
- Gameoverlay
- Pausemenü

