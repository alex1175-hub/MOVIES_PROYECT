const contenedor = document.getElementById('preview');
const formularioBusqueda = document.querySelector('#busqueda form');
const inputBusqueda = document.querySelector('#busqueda input[name="titulo"]');
fetch('/movies')
    .then(response => response.json())
    .then(data => {
        if (data && data.length > 0) {
            contenedor.innerHTML = '';
            data.forEach(movie => {
                const card = document.createElement('div');
                card.className = 'movie-card';
                const imagen = document.createElement('img');
                imagen.src = `/imagenes/${movie.name}.png`;
                imagen.alt = movie.name;
                imagen.width = 180;

                imagen.onerror = () => {
                    imagen.src = 'https://via.placeholder.com/180x260?text=Sin+Imagen';
                };
                const titulo = document.createElement('h3');
                titulo.textContent = movie.name;
                const boton = document.createElement('button');
                boton.className = 'btn btn-success w-100 mt-auto';
                boton.textContent = 'Ver Reseña';
                boton.name = "ver";
                boton.value = movie._id;

                card.appendChild(imagen);
                card.appendChild(titulo);
                card.appendChild(boton);

                contenedor.appendChild(card);
            });
        } else {
            contenedor.innerHTML = `
                <div class="mensaje-espera">
                    <p>No hay reseñas disponibles actualmente.</p>
                </div>
            `;
        }
    })
    .catch(error => {
        console.error('Error al conectar con el servidor:', error);
        contenedor.innerHTML = `
            <div class="mensaje-espera text-danger">
                <p>Error al cargar los datos del servidor.</p>
            </div>
        `;
    });

formularioBusqueda.addEventListener('submit', function (event) {
    event.preventDefault();
    const textoBusqueda = inputBusqueda.value.trim().toLowerCase();
    fetch('/movies')
        .then(response => response.json())
        .then(data => {
            contenedor.innerHTML = '';
            const resultados = data.filter(movie =>
                movie.name.toLowerCase().includes(textoBusqueda)
            );
            if (resultados.length > 0) {
                resultados.forEach(movie => {
                    const card = document.createElement('div');
                    card.className = 'movie-card';
                    const imagen = document.createElement('img');
                    imagen.src = `/imagenes/${movie.name}.png`;
                    imagen.alt = movie.name;
                    imagen.width = 180;
                    imagen.onerror = () => {
                        imagen.src = 'https://via.placeholder.com/180x260?text=Sin+Imagen';
                    };
                    const titulo = document.createElement('h3');
                    titulo.textContent = movie.name;
                    const boton = document.createElement('button');
                    boton.className = 'btn btn-success w-100 mt-auto';
                    boton.textContent = 'Ver Reseña';
                    boton.name = "ver";
                    boton.value = movie._id;
                    card.appendChild(imagen);
                    card.appendChild(titulo);
                    card.appendChild(boton);
                    contenedor.appendChild(card);
                });
            } else {
                contenedor.innerHTML = `
                    <div class="mensaje-espera">
                        <p>No se encontraron películas con ese nombre.</p>
                    </div>
                `;
            }
        })
        .catch(error => {
            console.error('Error en búsqueda:', error);
            contenedor.innerHTML = `
                <div class="mensaje-espera text-danger">
                    <p>Error al realizar la búsqueda.</p>
                </div>
            `;
        });
});