# encoding: utf-8
# Genera index.html (página independiente para GitHub Pages) a partir de
# tablero/index.html, la versión que corre dentro del tipo Dashboard de Claude.
# Uso, desde la raíz del repositorio: ruby -Ku scripts/armar_pagina_integrado.rb
cuerpo = File.read('tablero/index.html', encoding: 'UTF-8').sub(/\A<meta name="dash-one-writer">\s*/, '')
estilo = cuerpo[%r{<style>.*?</style>}m]
cuerpo = cuerpo.sub(estilo, '')
archivos = 'resumen:resumen_integrado.json oxi:tablero_oxi.json regalias:tablero_regalias.json ' \
           'regalias_tramite:tablero_regalias_tramite.json cocrea:tablero_cocrea.json municipios:municipios_focales.json'
pagina = <<~HTML
  <!doctype html>
  <html lang="es">
  <head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>Proyectos OxI, Regalías y CoCrea</title>
  <meta name="description" content="Seguimiento 2020–2026 de proyectos de Obras por Impuestos, Regalías (municipios PDET y ZOMAC) y CoCrea con un estado común: en trámite, aprobado, en ejecución, parado o terminado.">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Source+Sans+3:wght@400;600;700&family=Source+Serif+4:opsz,wght@8..60,400&display=swap">
  <link rel="stylesheet" href="web/tokens.css">
  #{estilo}
  <script src="https://cdnjs.cloudflare.com/ajax/libs/d3/7.9.0/d3.min.js"></script>
  <script src="web/dash.js" data-base="datos/" data-preload="no"
    data-datasets="resumen oxi regalias regalias_tramite cocrea municipios"
    data-files="#{archivos}"></script>
  </head>
  <body>
  <div id="dash-root">
  #{cuerpo.strip}
  <footer class="ox-pie">
    <p>Fuentes: Agencia de Renovación del Territorio, Departamento Nacional de Planeación (MapaInversiones y datos.gov.co) y registro público de CoCrea. Método y límites en la pestaña "Método y fuentes".</p>
    <p>Datos y scripts en el <a href="https://github.com/felipe95011015221-cell/Tablero-Proyectos-COCREA-REGALIAS-OXI">repositorio del proyecto</a>. Tablero de Obras por Impuestos en detalle: <a href="https://felipe95011015221-cell.github.io/obras-por-impuestos-colombia/">Obras por Impuestos Colombia</a>.</p>
  </footer>
  </div>
  </body>
  </html>
HTML
File.write('index.html', pagina)
puts "index.html: #{pagina.bytesize} bytes"
