**Diese Datei dient dazu, geloeste Bugs zu dokumentieren, sodass,falls die wieder auftauchen,wir die Bugs loesen koennen.**

## Switch Scene,use after free:
### Beschreibung
- Wenn man aus der Spielszene zurueck zum Menü geht, sturzt das Program ab. Dieser Fehler ist nach der Einfuehrung der `draw_grid()` Funktion aufgetreten. Hat etwas mit `Level.grid` zu tun. Es sieht so aus, als wuerde die Funktion `onUpdate()` von der alte Szene noch laufen, was den Fehler erklaeren wuerde, da die Funktion `onCleanup()` bereits ausgefuehrt wurde und `Level.grid` aus Heap geloescht wurde.  
### Loesung:
- Normaleweise wechselt man Szenen in der 'getInput()' Funktion mit diesen Zeilen 
``` 
        if (rl.isKeyDown(.m)) {                 
            try context.switchTo(SceneId.menu); 
            return;                        
        }                                       
```
Die Szene wird aufgeraumt durch `onCleanup()`.Danach laueft jedoch noch die `onUpdate()` Funktion zu Ende,genau da entsteht der Use-After-Free Fehler

