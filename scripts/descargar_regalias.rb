# encoding: utf-8
# Descarga de datos.gov.co los proyectos SGR (DNP-ProyectosSGR, mzgh-shtp) con BPIN desde 2020
# y su localización (DNP-LocalizacionProyecto, xikz-44ja) en los municipios PDET/ZOMAC.
# Uso: ruby descargar_regalias.rb municipios_focales.json salida_sgr.json salida_localizacion.json
require 'json'; require 'net/http'; require 'uri'
def socrata(ds, params)
  filas = []; offset = 0
  loop do
    q = URI.encode_www_form(params.merge('$limit' => 50000, '$offset' => offset, '$order' => ':id'))
    uri = URI("https://www.datos.gov.co/resource/#{ds}.json?#{q}")
    res = nil
    3.times { res = Net::HTTP.get_response(uri); break if res.is_a?(Net::HTTPSuccess); sleep 3 }
    raise "#{ds}: HTTP #{res.code} #{res.body[0, 200]}" unless res.is_a?(Net::HTTPSuccess)
    lote = JSON.parse(res.body.force_encoding('UTF-8'))
    filas.concat(lote); offset += lote.size
    STDERR.puts "#{ds}: #{filas.size}"
    break if lote.size < 50000
  end
  filas
end
mun = JSON.parse(File.read(ARGV[0], encoding: 'UTF-8')).map { |m| m['codigo_dane'] }
sgr = socrata('mzgh-shtp', '$where' => "codigobpin >= '2020'")
File.write(ARGV[1], JSON.generate(sgr))
loc = []
mun.each_slice(120) do |grupo|
  lista = grupo.map { |c| "'#{c}'" }.join(',')
  loc.concat(socrata('xikz-44ja', '$select' => 'bpin,codigomunicipio,municipio,codigodepartamento,departamento',
                                  '$where' => "codigomunicipio in(#{lista}) AND bpin >= '2020'"))
end
File.write(ARGV[2], JSON.generate(loc))
STDERR.puts "SGR desde 2020: #{sgr.size}; localizaciones en municipios focales: #{loc.size}"

# --- Base general de MapaInversiones (cf9k-55fw): ciclo completo de los proyectos SGR desde 2020 ---
if ARGV[3]
  basicos = socrata('cf9k-55fw', '$select' => 'bpin,nombreproyecto,estadoproyecto,subestadoproyecto,horizonte,sector,entidadresponsable,valortotalproyecto,valorvigenteproyecto,valorobligacionproyecto,valorpagoproyecto,totalbeneficiario',
                                 '$where' => "tipoproyecto='Sgr' AND bpin >= '2020'")
  File.write(ARGV[3], JSON.generate(basicos))
  STDERR.puts "Base general SGR desde 2020: #{basicos.size}"
end
