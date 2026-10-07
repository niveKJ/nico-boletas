# NICO Boletas

Aplicación web en Ruby on Rails para registrar boletas de compra chilenas. El usuario sube una boleta en PDF o imagen, la IA extrae los datos, el formulario se precarga y la persona revisa, corrige y guarda en PostgreSQL.

**Demo en producción:** https://nico-boletas.onrender.com

> El demo usa el plan gratuito de Render: si el servidor estuvo inactivo, la primera carga puede tardar cerca de un minuto.

## Flujo de la aplicación

1. El usuario sube una boleta en PDF, JPG o PNG.
2. La aplicación envía el contenido a Gemini y recibe los datos estructurados.
3. El formulario de revisión se precarga con comercio, RUT, fecha, monto total e ítems, y muestra la boleta original al lado para comparar.
4. El usuario corrige lo que haga falta y confirma. Recién ahí la boleta queda como completada.
5. El listado permite consultar, editar y eliminar las boletas, con el total de las confirmadas.

Si la IA no logra leer la boleta, el registro no se pierde: queda en estado de error y el usuario puede ingresar los datos a mano.

## Cómo se resolvió el problema

- **Dos caminos de extracción.** Si el PDF ya trae texto (boleta electrónica), se extrae con `pdf-reader` y se envía solo el texto: es más rápido y más barato. Si es una foto o un PDF escaneado, se envía el archivo y el OCR lo hace Gemini con su modelo de visión, sin instalar un motor de OCR aparte.
- **Salida estructurada.** La llamada usa `responseMimeType: "application/json"` con un `responseSchema`, de modo que Gemini queda obligado a responder con los campos esperados y no hay que rescatar el JSON desde texto libre.
- **Modelos alternativos.** Si el modelo principal está saturado (503), sin cuota (429) o fue retirado (404), el servicio prueba con el siguiente de la lista: `gemini-3.8-flash`, `gemini-3.5-flash` y `gemini-3.1-flash-lite`.
- **Normalización.** El monto se guarda como entero en pesos chilenos (`"$11.332"`, `11332.0` y `"11.332,00"` terminan en `11332`) y la fecha acepta `AAAA-MM-DD` y `DD/MM/AAAA`.
- **La persona decide.** Lo que extrae la IA nunca se da por bueno: la boleta pasa por los estados `procesando → extraido → completado` (o `error`), y solo se marca como completada cuando alguien la revisa y confirma.

Toda la integración con Gemini vive en `app/services/gemini_extractor.rb`.

## Prompt usado con Gemini

```
Eres un extractor de datos de boletas y facturas chilenas. Lee el documento y devuelve un JSON con estos campos:
- nombre_comercio: razón social o nombre de fantasía del emisor.
- rut_comercio: RUT del emisor con formato XX.XXX.XXX-X.
- fecha: fecha de emisión en formato YYYY-MM-DD (las boletas chilenas la escriben como DD/MM/AAAA).
- monto_total: total final pagado en pesos chilenos, como número entero sin puntos ni símbolos.
- items: lista con la descripción de cada producto o servicio comprado.
Si un dato no aparece o no se puede leer, usa null. No inventes datos.
```

Se envía con `temperature: 0` para que la extracción sea lo más repetible posible. Cuando el PDF trae texto, el prompt va seguido de `Texto de la boleta:` y el contenido; cuando es imagen, va acompañado del archivo en base64.

## Instalación y ejecución local

Requisitos: Ruby 3.4.10, PostgreSQL en ejecución y una API key de Gemini (gratis en [aistudio.google.com](https://aistudio.google.com/app/apikey)).

```bash
# 1. Clonar el repositorio
git clone https://github.com/niveKJ/nico-boletas.git
cd nico-boletas

# 2. Instalar dependencias
bundle install

# 3. Configurar la API key
cp .env.example .env
# Editar .env y pegar tu GEMINI_API_KEY

# 4. Crear la base de datos
bin/rails db:prepare

# 5. Iniciar la aplicación (compila los estilos y levanta el servidor)
bin/dev
```

Abrir [http://localhost:3000](http://localhost:3000).

## Variables de entorno

| Variable | Obligatoria | Descripción |
|---|---|---|
| `GEMINI_API_KEY` | Sí | API key de Google Gemini. |
| `GEMINI_MODEL` | No | Modelo principal. Por defecto `gemini-3.8-flash`. |
| `DATABASE_URL` | Solo en producción | URL de conexión a PostgreSQL. |
| `RAILS_MASTER_KEY` | Solo en producción | Clave para las credenciales cifradas de Rails. |

## Pruebas y calidad

```bash
bundle exec rspec   # modelo, extractor de Gemini (con la API simulada) y guardado/eliminación
bin/rubocop         # estilo
bin/brakeman        # análisis de seguridad
```

## Despliegue

La aplicación está desplegada en Render con el runtime de Ruby. El script `bin/render-build.sh` instala las gemas, compila los assets y ejecuta las migraciones. En el servicio se configuran `GEMINI_API_KEY`, `DATABASE_URL` y `RAILS_MASTER_KEY`.

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| Backend | Ruby on Rails 8.1 |
| Base de datos | PostgreSQL |
| Archivos adjuntos | Active Storage |
| IA y OCR | Gemini API (`gemini-3.8-flash`, con modelos alternativos) |
| Lectura de PDF con texto | `pdf-reader` |
| Cliente HTTP | `faraday` |
| Frontend | Vistas ERB y Stimulus |
| Pruebas | RSpec y FactoryBot |

## Limitaciones conocidas

- **Sin autenticación.** Cualquier persona con el enlace puede ver y subir boletas. Es aceptable para un demo, no para producción.
- **Archivos en disco local.** En el plan gratuito de Render el disco no es persistente, así que los archivos originales pueden perderse en un nuevo despliegue. Los datos extraídos sí se conservan en PostgreSQL.
- **Extracción dentro del request.** La llamada a Gemini ocurre mientras el usuario espera; una boleta suele tardar pocos segundos.

## Qué mejoraría con más tiempo

- **Procesamiento en segundo plano:** mover la llamada a Gemini a un job y avisar al usuario cuando termine, para no bloquear el request.
- **Almacenamiento persistente:** guardar los archivos en S3 o similar.
- **Validación del RUT:** comprobar el dígito verificador y avisar cuando lo leído no es un RUT válido.
- **Confianza por campo:** marcar los datos en los que la IA tuvo menos certeza para que el usuario sepa dónde mirar primero.
- **Detección de duplicados:** avisar si ya existe una boleta con el mismo RUT, fecha y monto.
- **Autenticación:** que cada usuario vea solo sus boletas.
- **Pruebas del flujo completo:** cubrir subida, extracción y confirmación de punta a punta.
- **Exportación:** descargar el listado en CSV o Excel para uso contable.

## Uso de IA en el desarrollo

Además de la extracción con Gemini, desarrollé el proyecto con apoyo de Claude (Anthropic) como asistente de programación: para planificar la solución, escribir y revisar código, y depurar el despliegue.
