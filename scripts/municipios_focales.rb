# encoding: utf-8
# Lista de municipios PDET (datos.gov.co idrk-ba8y) y ZOMAC (Decreto 1650 de 2017, Anexo 2) con código DANE.
# Uso: ruby municipios_focales.rb decreto_1650_2017.htm pdet.json salida.json
require 'json'; require 'cgi'
html = File.read(ARGV[0], encoding: 'UTF-8')
t = CGI.unescapeHTML(html.gsub(%r{</t[dh]>}, '|').gsub(%r{</tr>}, "\n").gsub(/<[^>]+>/, ' ').gsub('&nbsp;', ' ')).gsub(/[ \t]+/, ' ')
zomac = {}
t.lines.each do |l|
  r = l.split('|').map { |c| CGI.unescapeHTML(c.strip) }.reject(&:empty?)
  i = r.index { |c| c =~ /^\d{5}$/ } or next
  zomac[r[i]] = { 'departamento' => r[i + 1], 'municipio' => r[i + 2] }
end
pdet = JSON.parse(File.read(ARGV[1], encoding: 'UTF-8'))
pd = pdet.each_with_object({}) { |p, h| h[p['cod_muni'].to_s.rjust(5, '0')] = p }
codigos = (zomac.keys + pd.keys).uniq.sort
filas = codigos.map do |c|
  z = zomac[c]; p = pd[c]
  { 'codigo_dane' => c,
    'departamento' => p ? p['nom_depto'] : z['departamento'],
    'municipio' => p ? p['nom_muni'] : z['municipio'],
    'pdet' => !p.nil?, 'zomac' => !z.nil?,
    'subregion_pdet' => p ? p['nom_subreg'] : nil,
    'tipo' => p && z ? 'PDET y ZOMAC' : p ? 'Solo PDET' : 'Solo ZOMAC' }
end
File.write(ARGV[2], JSON.pretty_generate(filas))
STDERR.puts "ZOMAC #{zomac.size}, PDET #{pd.size}, total #{filas.size}; ambos #{filas.count { |f| f['pdet'] && f['zomac'] }}"
