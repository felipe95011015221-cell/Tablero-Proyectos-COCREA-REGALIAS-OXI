# Tablero de proyectos CoCrea, Regalías y Obras por Impuestos

Seguimiento 2020–2026 de los proyectos de tres mecanismos de inversión en Colombia, con un mismo estado para poder compararlos: **en trámite, no aprobado, aprobado sin iniciar, en ejecución, parado, terminado o sin información**.

**Ver el tablero:** <https://felipe95011015221-cell.github.io/Tablero-Proyectos-COCREA-REGALIAS-OXI/>

| Mecanismo | Proyectos | Cobertura | Fuente |
|---|---|---|---|
| Obras por Impuestos (OxI) | 1.021 | Aprobados 2020–2025 y trámite 2026, todo el país | Agencia de Renovación del Territorio y MapaInversiones del DNP |
| Regalías (SGR) | 21.005 | BPIN desde 2020 en los 347 municipios PDET y ZOMAC | DNP en datos.gov.co |
| CoCrea | 2.331 | Convocatorias 2020 a 2026, todo el país | Registro público de colombiacrea.org |

## Qué tiene

- **Comparado:** los tres mecanismos por estado, año, departamento y sector, con filtros por año, territorio (PDET/ZOMAC) y departamento.
- **Una pestaña por mecanismo:** filtros, gráficos por año, grupo, motivo de parada y departamento, y la lista de proyectos con su valor en pesos completos. Cada nombre abre la ficha del proyecto en MapaInversiones o en colombiacrea.org.
- **CoCrea:** valor total del proyecto y valor solicitado a CoCrea.
- **Método y fuentes:** cómo se asigna cada estado y los límites de los datos.

## Cómo se define "parado"

Un proyecto está parado si la fuente lo marca inactivo o suspendido, si su plazo terminó sin avance físico reportado, o si se aprobó y no inició antes de que venciera su plazo. En CoCrea, si el aval venció sin que el proyecto entrara en ejecución. Es una alerta para revisar, no una prueba de incumplimiento.

## Contenido

```
index.html        El tablero (página que publica GitHub Pages)
web/dash.js       Carga los datos y dibuja gráficos y tablas
web/tokens.css    Tipografía, espacios y estilos base
tablero/          El tablero tal como corre en Claude (fuente de index.html)
datos/            Datos en JSON: un archivo por mecanismo y un resumen agregado
scripts/          Scripts en Ruby que descargan, unen y clasifican los datos
```

## Actualizar

- **Cambiar el tablero:** edita `tablero/index.html` y vuelve a generar la página con `ruby -Ku scripts/armar_pagina.rb`.
- **Ver en tu computador:** el navegador no carga los datos si abres `index.html` con doble clic. Sirve la carpeta con `ruby -run -e httpd . -p 8000` o `python3 -m http.server 8000` y abre <http://localhost:8000>.
- **Regenerar los datos:** `scripts/descargar_regalias.rb` descarga regalías y localizaciones de datos.gov.co, `scripts/municipios_focales.rb` arma la lista PDET/ZOMAC y `scripts/integrar.rb` une los tres mecanismos. Los datos de OxI salen del repositorio [obras-por-impuestos-colombia](https://github.com/felipe95011015221-cell/obras-por-impuestos-colombia).

## Límites

- Los años no significan lo mismo en las tres fuentes: aprobación (OxI), registro del BPIN (Regalías) y convocatoria (CoCrea).
- En Regalías, los proyectos en formulación traen valores escritos por quien formula; los de más de un billón de pesos se tratan como atípicos y no se suman.
- CoCrea no publica uno a uno los postulados no avalados, y sus primeras convocatorias no traen valores.
- Los datos son una copia del 4 y 5 de noviembre de 2026.
