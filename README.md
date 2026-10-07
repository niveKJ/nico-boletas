# NICO Boletas

Aplicación web en Ruby on Rails que permite subir boletas de compra chilenas (PDF o imagen), extraer sus datos automáticamente con IA y guardarlos en una base de datos PostgreSQL.

## Flujo de la aplicación

1. El usuario sube una boleta en formato PDF, JPG o PNG.
2. La aplicación extrae el texto del PDF con `pdf-reader`. Si el PDF no contiene texto (escaneado o imagen), envía el archivo directamente como binario.
3. El texto o la imagen se envía a **Gemini** (`gemini-3.1-flash-lite`) con un prompt que solicita los datos estructurados en JSON.
4. El formulario de revisión se precarga con los campos extraídos: comercio, RUT, fecha, monto total e ítems.
5. El usuario revisa, corrige si es necesario y confirma. Los datos se guardan en PostgreSQL.
6. El listado de boletas muestra todas las registradas con sus métricas agregadas.

## Requisitos

- Ruby 3.4+
- Rails 8.1
- PostgreSQL
- `poppler-utils` (para vista previa de PDFs)

```bash
# Ubuntu/Debian
sudo apt-get install poppler-utils

# macOS
brew install poppler
```

## Instalación

```bash
# 1. Clonar el repositorio
git clone https://github.com/niveKJ/nico-boletas.git
cd nico-boletas

# 2. Instalar dependencias
bundle install

# 3. Configurar variables de entorno
cp .env.example .env
# Editar .env y agregar tu GEMINI_API_KEY

# 4. Crear y migrar la base de datos
rails db:create db:migrate

# 5. Iniciar el servidor
rails server
```

Abre [http://localhost:3000](http://localhost:3000) en tu navegador.

## Variables de entorno

Crea un archivo `.env` en la raíz del proyecto:

```
GEMINI_API_KEY=tu_api_key_aqui
```

Obtén tu API key gratis en [aistudio.google.com](https://aistudio.google.com).

## Prompt utilizado con Gemini

```
Extrae de esta boleta chilena estos campos en JSON puro sin markdown:
{
  "nombre_comercio": "...",
  "rut_comercio": "XX.XXX.XXX-X",
  "fecha": "YYYY-MM-DD",
  "monto_total": numero_entero,
  "items": ["item1", "item2"]
}
Solo JSON, sin explicaciones.
```

**Estrategia de extracción:**
- PDFs con texto: se extrae el texto con `pdf-reader` y se envía como contexto al prompt (más rápido y económico).
- PDFs escaneados o imágenes: se codifica el archivo en base64 y se envía directamente a la API de visión de Gemini.

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| Backend | Ruby on Rails 8.1 |
| Base de datos | PostgreSQL |
| Archivos adjuntos | ActiveStorage |
| Extracción de IA | Gemini API (`gemini-3.1-flash-lite`) |
| Lectura de PDFs | `pdf-reader` |
| HTTP client | `faraday` |
| Frontend | Stimulus JS + estilos inline (sin dependencia de Tailwind en producción) |
| Vista previa PDF | `poppler` vía `image_processing` |

## Qué mejoraría con más tiempo

- **Confianza por campo**: mostrar un indicador de certeza junto a cada dato extraído, para que el usuario sepa cuáles revisar con más atención.
- **Procesamiento en background**: mover la llamada a Gemini a un job asíncrono (Sidekiq) con polling desde el frontend, para no bloquear el request HTTP mientras la IA responde.
- **Soporte multi-página**: actualmente se procesan hasta 2.000 caracteres del PDF; con más tiempo se procesarían todas las páginas con chunking inteligente.
- **Tests de integración**: cubrir el flujo completo de subida → extracción → guardado con RSpec y VCR para las llamadas a la API.
- **Exportación**: permitir descargar el listado de boletas en CSV o Excel para uso contable.
- **Autenticación**: agregar Devise para que cada usuario vea solo sus boletas.
