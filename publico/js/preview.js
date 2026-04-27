function limpiarNombre(nombre) {
    return nombre
        .toLowerCase()
        .trim()
        .replace(/\s+/g, '-')        // espacios → guiones
        .replace(/[^\w-]/g, '');     // quita acentos y símbolos
}

// Función para cargar todas las reseñas desde el servidor
fetch('/movies')
    .then(response => response.json())
    .then(data => {
        const contenedor = document.getElementById('preview');

        // Si el servidor responde con datos
        if (data && data.length > 0) {
            // 1. Quitamos el mensaje de "Reseñas en Preview"
            contenedor.innerHTML = ''; 

            // 2. Recorremos TODA la base de datos
            data.slice(0, 9).forEach(movie => {
                // Creamos el contenedor de columna (Bootstrap col)
                // col-12: 1 columna en móvil | col-md-6: 2 en tablets | col-lg-4: 3 en escritorio
                const col = document.createElement('div');
                col.className = 'col-12 col-md-6 col-lg-4';

                // Creamos la tarjeta (Bootstrap card)
                const card = document.createElement('div');
                card.className = 'card h-100 shadow-sm border-0 movie-card';

                // Imagen con clases de Bootstrap
                const imagen = document.createElement('img');
                const nombreArchivo = limpiarNombre(movie.name); // nuevo
                imagen.src = `imagenes/${nombreArchivo}.png`;    // cambiado

                imagen.alt = movie.name;
                imagen.className = 'card-img-top p-3';
                imagen.style.objectFit = 'contain';
                imagen.style.height = '250px';

                // Imagen de respaldo
                imagen.onerror = () => { 
                    imagen.src = 'https://via.placeholder.com/180x260?text=Sin+Imagen'; 
                };

                // Cuerpo de la tarjeta
                const cardBody = document.createElement('div');
                cardBody.className = 'card-body d-flex flex-column text-center';

                // Título de la película
                const titulo = document.createElement('h5');
                titulo.className = 'card-title fw-bold';
                titulo.textContent = movie.name;

                // Botón de acción
                const boton = document.createElement('button');
                boton.className = 'btn btn-success w-100 mt-auto';
                boton.textContent = 'Ver Reseña';
                 boton.name = "ver";             // Para que resena_ver.js lo identifique
                 boton.value = movie._id;        // Para pasar el ID de la película


                // Ensamblar la tarjeta
                cardBody.appendChild(titulo);
                cardBody.appendChild(boton);
                
                card.appendChild(imagen);
                card.appendChild(cardBody);

                // Meter la tarjeta en la columna y la columna en el row (#preview)
                col.appendChild(card);
                contenedor.appendChild(col);
            });
        } else {
            contenedor.innerHTML = '<div class="col-12 text-center"><p>No hay reseñas disponibles actualmente.</p></div>';
        }
    })
    .catch(error => {
        console.error('Error al conectar con el servidor:', error);
        const contenedor = document.getElementById('preview');
        contenedor.innerHTML = '<div class="col-12 text-center text-danger"><p>Error al cargar los datos del servidor.</p></div>';
    });