// Función para cargar las 10 primeras reseñas desde el servidor
fetch('/movies')
    .then(response => response.json())
    .then(data => {
        const contenedor = document.getElementById('preview');

        // Si el servidor responde con datos
        if (data && data.length > 0) {
            // 1. Quitamos el mensaje de "Reseñas en Preview"
            contenedor.innerHTML = ''; 

            // 2. Recorremos TODA la base de datos
            data.forEach(movie => {
                // Creamos el elemento de la tarjeta
                const card = document.createElement('div');
                card.className = 'movie-card';

                // Imagen (ajusta la ruta según tu servidor)
                const imagen = document.createElement('img');
                imagen.src = `/imagenes/${movie.name}.png`; 
                imagen.alt = movie.name;
                imagen.width = 180;
                // Imagen de respaldo si no encuentra la original
                imagen.onerror = () => { imagen.src = 'https://via.placeholder.com/180x260?text=Sin+Imagen'; };

                // Título de la película
                const titulo = document.createElement('h3');
                titulo.textContent = movie.name;

                // Botón de acción
                const boton = document.createElement('button');
                boton.className = 'btn btn-success w-100 mt-auto';
                boton.textContent = 'Ver Reseña';
                boton.name = "ver";
                boton.value = movie._id;

                // Ensamblar la tarjeta
                card.appendChild(imagen);
                card.appendChild(titulo);
                card.appendChild(boton);

                // Agregar al contenedor principal
                contenedor.appendChild(card);
            });
        } else {
            contenedor.innerHTML = '<div class="mensaje-espera"><p>No hay reseñas disponibles actualmente.</p></div>';
        }
    })
    .catch(error => {
        console.error('Error al conectar con el servidor:', error);
        const contenedor = document.getElementById('preview');
        contenedor.innerHTML = '<div class="mensaje-espera text-danger"><p>Error al cargar los datos del servidor.</p></div>';
    });