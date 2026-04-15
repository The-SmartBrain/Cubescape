# Cubescape
Small Puzzle Game for playing while lessons

## Allgemein

### Funktionsweise
- Umkippen 
- Die Form des Spielsteins ist levelabhängig
- keine Grenze fuer die Nutzung von Effekten
- Perspektivische Kamera
- Kamera folgt spieler
- Voxel aussehen
- Kein Undo, sondern feste Checkpoints bei langen Levels
- Kronen-System: 3 Kronen (maximal) wenn man die von uns festgelegte Route findet; 2 Kronen: x bis y Zuege; 1 Krone: Level geschafft;
- Levels in Ebenen gruppieren. Man kann zur naechste Ebene, nur wenn mann genug Kronen hat
- Effekten werden nicht vor dem Start des Levels gewaehlt, sondern (auf dem Boden) im Level gefunden und dann auf einer Seite "geklebt"

### Quality Of Life Features
- GUI, um zu zeigen, was fuer Effekten auf welcher Seite man hat


## Steine/Hindernisse 
- Spikes, man stirbt sofort, es sei denn, man hat Ruestung auf die Seite, mit der man auf dem Stein tritt
- Bewegliche Steine/Barriere
- Loch
- Stein (einfache Wand)
- Verwirrungs-Stein, der die Steuerung vorübergehend ändert, rechts wird links , vorne wird hinten. Leicht versteckt. Nachdem man dadrauf getreten ist, kann man den Stein sehen 
- Schwacher Boden: Man kann nur einmal auf dem Stein treten. Nachdem man den Stein verlaessen hat, verschwindet der. 


## Effekte
- Portal("Loch") -> Man kann bestimmte Steine "ignorieren" --> Also z.B. damitr auf einen kleinen tein kippen, woi man sonst eigentlich nicht draufkippen könnte
- Ruestung -> Man stirbt nicht,wenn man auf z.B. einen Spike tritt . Es gibt zwei Arten: einmalige und permanente Ruestung
- Dash -> Man Dasht 2 Felder weiter, überspringt also eins nach dem umkippen. -> in diesem Zug 3 Felder gegangen

## Vielleicht 
- Hotkey zum Kamera vom Spieler lösen, um das Level anzuschauen




Anmerkung: Spielstein != Stein: Spielstein -> der Spieler/-in; Stein  -> Hindernisse.  
## Offene Fragen
