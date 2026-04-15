// Obtener datos del servidor
fetch('/movies')
    .then(response => response.json())
    .then(data => {
        const contenedor = document.getElementById('preview');

        data.forEach(movie => {

            // Crear formulario
            const form = document.createElement('form');

            // Campo ID
            const inputId = document.createElement('input');
            inputId.type = 'hidden';
            inputId.value = movie._id;
            //imagen
            const imagen = document.createElement('img');
            imagen.src = `/imagenes/${movie.name}.png`;
            imagen.alt = movie.name;
            imagen.width = 150; // opcional

            // Campo Nombre
            const titulo = document.createElement('h3');
            titulo.textContent = movie.name;

            // Botón
            const boton = document.createElement('button');
            boton.textContent = 'ver reseña';

            // Agregar elementos al formulario
            form.appendChild(inputId);
            form.appendChild(imagen);
            form.appendChild(titulo);
            form.appendChild(boton);

            // Agregar formulario al contenedor
            contenedor.appendChild(form);
        });
    })
    .catch(error => console.error('Error:', error));