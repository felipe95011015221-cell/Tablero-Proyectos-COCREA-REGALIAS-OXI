# encoding: utf-8
# Une Obras por Impuestos (ART + DNP), Regalías (DNP, municipios PDET/ZOMAC) y CoCrea (registro público)
# en una sola tabla de proyectos 2020–2026 con un estado común.
#
# Estados unificados (orden del ciclo):
#   1 En trámite · 2 No aprobado · 3 Aprobado sin iniciar · 4 En ejecución · 5 Parado · 6 Terminado · 7 Sin información
# "Parado": estado oficial (inactivo/suspendido) o plazo vencido sin avance; en CoCrea, aval vencido sin ejecución.
#
# Uso, desde data/integrado: ruby -Ku ../../scripts/integrado/integrar.rb
require 'json'

ANIO_CORTE = 2026
ESTADOS = { 1 => 'En trámite', 2 => 'No aprobado', 3 => 'Aprobado sin iniciar', 4 => 'En ejecución',
            5 => 'Parado', 6 => 'Terminado', 7 => 'Sin información' }

def leer(r) j = JSON.parse(File.read(r, encoding: 'UTF-8')); j.is_a?(Hash) ? (j['rows'] || j['data'] || j) : j end
def norm(s) s.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, '').upcase.gsub(/[^A-Z0-9 ]/, ' ').gsub(/\s+/, ' ').strip end
def corto(s, n = 180) s = s.to_s.gsub(/\s+/, ' ').strip; s.size > n ? s[0, n - 1].rstrip + '…' : s end
def fin_hor(h) h.to_s[/(\d{4})\s*$/, 1]&.to_i end

# Grupo de sector común a los tres mecanismos
def sector_grupo(s, mec)
  return 'Cultura' if mec == 'CoCrea'
  t = norm(s)
  case t
  when /VIAL|TRANSPORTE/ then 'Transporte y vías'
  when /ICBF|PRIMERA INFANCIA|INCLUSION/ then 'Inclusión e infancia'
  when /EDUCACION|TRABAJO/ then 'Educación'
  when /AGUA|SANEAMIENTO|VIVIENDA/ then 'Agua, saneamiento y vivienda'
  when /ENERGIA|MINAS|GAS/ then 'Energía'
  when /SALUD/ then 'Salud'
  when /AMBIENT|RIESGO|CLIMA/ then 'Ambiente y riesgo'
  when /AGRICULTURA|PRODUCTIV|RURAL/ then 'Agricultura y desarrollo rural'
  when /DEPORTE/ then 'Deporte'
  when /CULTURA/ then 'Cultura'
  when /TECNOLOGIA|TIC|CIENCIA/ then 'TIC y ciencia'
  else 'Gobierno y otros'
  end
end

# --- Municipios PDET / ZOMAC ---
focales = leer('municipios_focales.json')
foco_por_dane = focales.to_h { |m| [m['codigo_dane'], m] }
foco_por_nombre = {}
focales.each { |m| foco_por_nombre[[norm(m['departamento']), norm(m['municipio'])]] = m }
def tipo_foco(m) m ? m['tipo'] : 'Fuera de PDET/ZOMAC' end
def buscar_foco(fpn, dep, mun)
  d = norm(dep).sub(/^NARINO$/, 'NARINO')
  fpn[[d, norm(mun)]] || fpn.find { |(dd, mm), _| dd == d && (mm.start_with?(norm(mun)) || norm(mun).start_with?(mm)) }&.last
end

filas = []

# --- Obras por Impuestos: aprobados 2020–2025 con su ejecución en el DNP ---
apr = leer('../oxi/proyectos.json').to_h { |p| [p['id'], p] }
leer('../oxi/ejecucion.json').each do |e|
  next if e['anio'].to_i < 2020
  p = apr[e['id']]
  fis = e['avance_fisico'].to_f
  sub = e['subestado_dnp'].to_s
  est, motivo = if e['situacion_orden'] == 1 then [6, nil]
                elsif sub =~ /Inactivo/i then [5, 'Inactivo en el SUIFP']
                elsif e['vencido'] && fis == 0 then [5, 'Plazo vencido sin avance']
                elsif e['situacion_orden'] == 4 then [7, 'Viable sin seguimiento de obra en el SUIFP']
                elsif e['situacion_orden'] == 5 then [7, 'Sin ficha en MapaInversiones']
                else [4, e['vencido'] ? 'En ejecución con plazo vencido' : nil] end
  mun1 = e['municipio'].to_s.split(', ').first
  f = buscar_foco(foco_por_nombre, e['departamento'], mun1)
  filas << { 'id' => "oxi-#{e['bpin']}", 'mecanismo' => 'OxI', 'codigo' => e['bpin'], 'anio' => e['anio'],
             'nombre' => corto(e['nombre']), 'sector' => sector_grupo(p['sector'], 'OxI'), 'sector_fuente' => p['sector'],
             'entidad' => e['ministerio'], 'departamento' => e['departamento'], 'municipio' => e['municipio'],
             'dane' => f ? f['codigo_dane'] : '', 'foco' => tipo_foco(f), 'valor_cop' => e['valor_cop'],
             'estado' => ESTADOS[est], 'estado_orden' => est, 'estado_fuente' => "#{e['estado_dnp']} · #{sub}".sub(/ · $/, ''),
             'motivo' => motivo, 'avance' => fis > 0 ? fis : nil, 'horizonte' => e['horizonte'],
             'enlace' => "https://mapainversiones.dnp.gov.co/Home/FichaProyectosMenuAllUsers?Bpin=#{e['bpin']}" }
end

# --- Obras por Impuestos: trámite 2026 (listado ART, corte 3 jul 2026) ---
leer('../oxi/tramite.json').each do |t|
  f = foco_por_dane[t['codigo_dane'].to_s.rjust(5, '0')]
  filas << { 'id' => "oxi-t-#{t['bpin']}", 'mecanismo' => 'OxI', 'codigo' => t['bpin'], 'anio' => 2026,
             'nombre' => corto(t['nombre']), 'sector' => sector_grupo(t['linea'], 'OxI'), 'sector_fuente' => t['linea'],
             'entidad' => t['ministerio'], 'departamento' => t['departamento'], 'municipio' => t['municipio'],
             'dane' => t['codigo_dane'].to_s.rjust(5, '0'), 'foco' => tipo_foco(f), 'valor_cop' => t['costo_cop'],
             'estado' => ESTADOS[1], 'estado_orden' => 1, 'estado_fuente' => "Trámite ART · #{t['estado']}",
             'motivo' => t['estado'] == 'Devuelto con observaciones' ? 'Devuelto con observaciones' : nil, 'avance' => nil,
             'horizonte' => '', 'enlace' => "https://mapainversiones.dnp.gov.co/Home/FichaProyectosMenuAllUsers?Bpin=#{t['bpin']}" }
end

# --- Regalías: proyectos SGR desde 2020 en municipios PDET/ZOMAC ---
loc = leer('fuentes/localizacion_focal.json').group_by { |l| l['bpin'] }
sgr_ej = leer('fuentes/sgr_proyectos_2020.json').to_h { |x| [x['codigobpin'], x] }
SUB_ORDEN = { 'Terminado' => 6, 'En Ejecución' => 4, 'Aprobado' => 3, 'Viable' => 1, 'Formulación' => 1,
              'Desaprobado' => 2, 'No Aprobado' => 2, 'No Viable' => 2 }
basicos = leer('fuentes/sgr_basicos_2020.json').select { |b| loc[b['bpin']] }
# Un BPIN repetido: se queda el registro más avanzado del ciclo
basicos = basicos.group_by { |b| b['bpin'] }.map { |_, v| v.max_by { |b| SUB_ORDEN.fetch(b['estadoproyecto'], 0) } }
atipicos = 0
basicos.each do |b|
  ej = sgr_ej[b['bpin']]
  fis = ej && ej['ejecucionfisica'] ? ej['ejecucionfisica'].to_f : nil
  fin = fin_hor(b['horizonte'])
  vencido = fin && fin < ANIO_CORTE
  sin_avance = fis.nil? || fis == 0
  ep, sub = b['estadoproyecto'].to_s, b['subestadoproyecto'].to_s.gsub(/\s+/, ' ').strip
  est, motivo = case ep
                when 'Terminado' then [6, nil]
                when 'Formulación', 'Viable' then [1, sub =~ /Devuelto/i ? 'Devuelto a MGA' : nil]
                when 'Desaprobado', 'No Aprobado', 'No Viable' then [2, nil]
                when 'Aprobado'
                  vencido ? [5, 'Aprobado sin iniciar con plazo vencido'] : [3, nil]
                else # En Ejecución
                  if (ej && ej['estado'] == 'TERMINADO') || (fis && fis >= 99) then [6, nil]
                  elsif sub =~ /Inactivo/i then [5, 'Inactivo en el SUIFP']
                  elsif vencido && sin_avance then [5, 'Plazo vencido sin avance']
                  else [4, vencido ? 'En ejecución con plazo vencido' : nil] end
                end
  ls = loc[b['bpin']]
  danes = ls.map { |l| l['codigomunicipio'] }.uniq
  fs = danes.map { |d| foco_por_dane[d] }.compact
  valor = b['valortotalproyecto'].to_f.round
  atipico = valor > 1_000_000_000_000
  atipicos += 1 if atipico
  filas << { 'id' => "sgr-#{b['bpin']}", 'mecanismo' => 'Regalías', 'codigo' => b['bpin'], 'anio' => b['bpin'][0, 4].to_i,
             'nombre' => corto(b['nombreproyecto']), 'sector' => sector_grupo(b['sector'], 'Regalías'), 'sector_fuente' => b['sector'],
             'entidad' => corto(b['entidadresponsable'], 90),
             'departamento' => ls.map { |l| l['departamento'] }.uniq.size > 1 ? 'Varios departamentos' : ls.first['departamento'],
             'municipio' => danes.size > 1 ? "Varios (#{danes.size})" : ls.first['municipio'],
             'dane' => fs.map { |f| f['codigo_dane'] }.join('|'),
             'foco' => fs.size == 1 ? fs.first['tipo'] : (fs.any? { |f| f['pdet'] } ? 'Solo PDET' : 'Solo ZOMAC'),
             'valor_cop' => atipico ? nil : valor, 'valor_atipico' => atipico ? valor : nil,
             'estado' => ESTADOS[est], 'estado_orden' => est, 'estado_fuente' => "#{ep} · #{sub}".sub(/ · $/, ''),
             'motivo' => motivo, 'avance' => fis, 'horizonte' => b['horizonte'],
             'enlace' => "https://mapainversiones.dnp.gov.co/Home/FichaProyectosMenuAllUsers?Bpin=#{b['bpin']}" }
end

# --- CoCrea: registro público, convocatorias 2020–2026 ---
leer('fuentes/cocrea/registro_cocrea.json').each do |c|
  conv = c['convocatoria'].to_i
  # Aval vigente: 2025 PAI 2 años; 2025 PAT/PAP 1 año; 2026 vigente; 2020–2024 ya vencidos (ver reglas_vigencia.json)
  aval_vigente = conv == 2026 || (conv == 2025 && c['modalidad'] == 'PAI')
  est, motivo = case c['estado']
                when 'Ejecutado' then [6, nil]
                when 'En ejecución' then [4, nil]
                else aval_vigente ? [3, nil] : [5, 'Aval vencido sin ejecución']
                end
  f = buscar_foco(foco_por_nombre, c['departamento'], c['municipio'])
  valor = c['valor_total'].to_f > 0 ? c['valor_total'].to_f : c['partida'].to_f
  filas << { 'id' => "cc-#{c['codigo']}", 'mecanismo' => 'CoCrea', 'codigo' => c['codigo'], 'anio' => conv,
             'nombre' => corto(c['nombre']), 'sector' => 'Cultura', 'sector_fuente' => c['sector'].to_s,
             'entidad' => corto(c['proponente'], 90), 'departamento' => c['departamento'].to_s, 'municipio' => c['municipio'].to_s,
             'dane' => f ? f['codigo_dane'] : '', 'foco' => tipo_foco(f), 'valor_cop' => valor > 0 ? valor.round : nil,
             # Valor solicitado a CoCrea (requested_budget del registro; en el archivo de origen se llama "partida")
             'valor_solicitado_cop' => c['partida'].to_f > 0 ? c['partida'].to_f.round : nil,
             'estado' => ESTADOS[est], 'estado_orden' => est, 'estado_fuente' => "#{c['estado']} · #{c['modalidad']}",
             'motivo' => motivo, 'avance' => nil, 'horizonte' => '', 'enlace' => c['enlace'] }
end

# Nombres de departamento y municipio iguales en las tres fuentes
DEPTOS = ['Amazonas', 'Antioquia', 'Arauca', 'Atlántico', 'Bogotá, D.C.', 'Bolívar', 'Boyacá', 'Caldas', 'Caquetá', 'Casanare',
          'Cauca', 'Cesar', 'Chocó', 'Córdoba', 'Cundinamarca', 'Guainía', 'Guaviare', 'Huila', 'La Guajira', 'Magdalena', 'Meta',
          'Nariño', 'Norte de Santander', 'Putumayo', 'Quindío', 'Risaralda', 'San Andrés y Providencia', 'Santander', 'Sucre',
          'Tolima', 'Valle del Cauca', 'Vaupés', 'Vichada']
DEP_NORM = DEPTOS.to_h { |d| [norm(d), d] }.merge('BOGOTA D C' => 'Bogotá, D.C.', 'BOGOTA' => 'Bogotá, D.C.',
  'ARCHIPIELAGO DE SAN ANDRES PROVIDENCIA Y SANTA CATALINA' => 'San Andrés y Providencia', 'SAN ANDRES' => 'San Andrés y Providencia',
  'VALLE' => 'Valle del Cauca', 'GUAJIRA' => 'La Guajira')
MINUS = %w[de del la las los y e el en]
def titulo(s) s.to_s.downcase.split(' ').each_with_index.map { |w, i| i > 0 && MINUS.include?(w) ? w : w.sub(/^\p{L}/) { |c| c.upcase } }.join(' ') end
filas.each do |f|
  d = f['departamento'].to_s
  f['departamento'] = if d.empty? then 'Sin departamento'
                      elsif d =~ /\||Varios/ then 'Varios departamentos'
                      else DEP_NORM[norm(d)] || titulo(d) end
  m = f['municipio'].to_s
  f['municipio'] = m == m.upcase ? titulo(m) : m
end

ids = filas.map { |f| f['id'] }
dups = ids.group_by(&:itself).select { |_, v| v.size > 1 }.keys
raise "ids repetidos: #{dups.first(5)}" unless dups.empty?
filas.each { |f| f.delete_if { |_, v| v.nil? } }
File.write('proyectos_integrados.json', JSON.generate(filas))

resumen = Hash.new { |h, k| h[k] = Hash.new(0) }
filas.each { |f| resumen[f['mecanismo']][f['estado']] += 1 }
STDERR.puts "#{filas.size} proyectos; valores atípicos excluidos: #{atipicos}"
resumen.each { |m, h| STDERR.puts "#{m}: #{h.values.sum} · #{h.sort_by { |k, _| ESTADOS.key(k) }.map { |k, v| "#{k} #{v}" }.join(', ')}" }
STDERR.puts "Tamaño: #{File.size('proyectos_integrados.json') / 1024} KB"

# --- Archivos para el tablero: uno por mecanismo, con solo los campos que muestra ---
# El código (BPIN o código CoCrea) identifica cada fila dentro de su archivo; el mecanismo lo pone el archivo.
CAMPOS = %w[codigo anio nombre sector entidad departamento municipio dane foco valor_cop valor_solicitado_cop valor_atipico estado motivo avance horizonte estado_fuente enlace]
def liviano(f, mec)
  g = f.slice(*CAMPOS)
  g.delete('enlace') unless mec == 'CoCrea'   # OxI y Regalías: el enlace se arma con el BPIN
  g['nombre'] = corto(g['nombre'], mec == 'Regalías' ? 110 : 140)
  g['entidad'] = corto(g['entidad'], 60) if g['entidad']
  g['estado_fuente'] = corto(g['estado_fuente'].to_s.split(' · ').last, 50) if g['estado_fuente']
  g['avance'] = g['avance'].round(1) if g['avance']
  g
end
archivos = {
  'tablero_oxi.json' => ->(f) { f['mecanismo'] == 'OxI' },
  'tablero_cocrea.json' => ->(f) { f['mecanismo'] == 'CoCrea' },
  'tablero_regalias.json' => ->(f) { f['mecanismo'] == 'Regalías' && f['estado_orden'] != 1 },
  'tablero_regalias_tramite.json' => ->(f) { f['mecanismo'] == 'Regalías' && f['estado_orden'] == 1 },
}
archivos.each do |arch, cond|
  sel = filas.select(&cond).map { |f| liviano(f, f['mecanismo']) }
  File.write(arch, JSON.generate(sel))
  STDERR.puts "#{arch}: #{sel.size} filas, #{File.size(arch) / 1024} KB"
end

# Resumen agregado para la vista comparada: proyectos y valor por mecanismo, año, estado, departamento, sector y foco
cubo = Hash.new { |h, k| h[k] = { 'proyectos' => 0, 'valor_cop' => 0, 'valor_solicitado_cop' => 0 } }
filas.each do |f|
  k = [f['mecanismo'], f['anio'], f['estado'], f['estado_orden'], f['departamento'], f['sector'], f['foco']]
  cubo[k]['proyectos'] += 1
  cubo[k]['valor_cop'] += f['valor_cop'].to_i
  cubo[k]['valor_solicitado_cop'] += f['valor_solicitado_cop'].to_i
end
res = cubo.map do |(m, a, e, o, d, s, fo), v|
  { 'mecanismo' => m, 'anio' => a, 'estado' => e, 'estado_orden' => o, 'departamento' => d, 'sector' => s, 'foco' => fo }.merge(v)
end
File.write('resumen_integrado.json', JSON.generate(res))
STDERR.puts "resumen_integrado.json: #{res.size} filas, #{File.size('resumen_integrado.json') / 1024} KB"
