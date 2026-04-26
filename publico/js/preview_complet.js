function limpiarNombre(nombre) { 
    return nombre
        .toLowerCase()
        .trim()
        .replace(/\s+/g, '-')        // espacios → guiones
        .replace(/[^\w-]/g, '');     // quitar símbolos
}

const contenedor = document.getElementById('preview');

const formularioBusqueda = document.querySelector('#busqueda form');
const inputBusqueda = document.querySelector('#busqueda input[name="titulo"]');

let hayBusquedaActiva = false;

// =====================================
// CREAR TARJETAS DE PELÍCULAS
// =====================================
function crearTarjetas(peliculas) {
    contenedor.innerHTML = '';

    if (!peliculas || peliculas.length === 0) {
        contenedor.innerHTML = `
            <div class="col-12 text-center">
                <p>No hay reseñas disponibles actualmente.</p>
            </div>
        `;
        return;
    }

    peliculas.forEach(movie => {
        const col = document.createElement('div');
        col.className = 'col-12 col-md-6 col-lg-4';

        const card = document.createElement('div');
        card.className = 'card h-100 shadow-sm border-0 movie-card';

        const imagen = document.createElement('img');

        const nombreArchivo = limpiarNombre(movie.name);
        imagen.src = `imagenes/${nombreArchivo}.png`;
        imagen.alt = movie.name;
        imagen.className = 'card-img-top p-3';
        imagen.style.objectFit = 'contain';
        imagen.style.height = '250px';

        imagen.onerror = () => {
            imagen.src = 'https://via.placeholder.com/180x260?text=Sin+Imagen';
        };

        const cardBody = document.createElement('div');
        cardBody.className = 'card-body d-flex flex-column text-center';

        const titulo = document.createElement('h5');
        titulo.className = 'card-title fw-bold';
        titulo.textContent = movie.name;

        const boton = document.createElement('button');
        boton.className = 'btn btn-success w-100 mt-auto';
        boton.textContent = 'Ver Reseña';
        boton.name = 'ver';
        boton.value = movie._id;

        cardBody.appendChild(titulo);
        cardBody.appendChild(boton);
        card.appendChild(imagen);
        card.appendChild(cardBody);
        col.appendChild(card);
        contenedor.appendChild(col);
    });
}

// =====================================
// CARGAR PELÍCULAS
// =====================================
function cargarPeliculas() {
    if (hayBusquedaActiva) return;

    fetch('/movies')
        .then(response => response.json())
        .then(data => crearTarjetas(data))
        .catch(error => {
            console.error('Error al conectar con el servidor:', error);

            contenedor.innerHTML = `
                <div class="col-12 text-center text-danger">
                    <p>Error al cargar los datos del servidor.</p>
                </div>
            `;
        });
}

// =====================================
// INICIO
// =====================================
cargarPeliculas();
setInterval(cargarPeliculas, 5000);


// =====================================
// BÚSQUEDA (SOLO SI EXISTE)
// =====================================
if (formularioBusqueda && inputBusqueda) {

    formularioBusqueda.addEventListener('submit', function (event) {
        event.preventDefault();

        let textoBusqueda = inputBusqueda.value.trim();

        textoBusqueda = sanitizer
            .limpiarSeguro(textoBusqueda)
            .toLowerCase();

        hayBusquedaActiva = textoBusqueda.length > 0;

        if (!textoBusqueda) {
            hayBusquedaActiva = false;
            cargarPeliculas();
            return;
        }

        fetch('/movies')
            .then(response => response.json())
            .then(data => {

                const resultados = data.filter(movie =>
                    movie.name.toLowerCase().includes(textoBusqueda)
                );

                crearTarjetas(resultados);
            })
            .catch(error => console.error('Error en búsqueda:', error));
    });

    inputBusqueda.addEventListener('input', () => {
        if (inputBusqueda.value.trim() === '') {
            hayBusquedaActiva = false;
            cargarPeliculas();
        }
    });
}