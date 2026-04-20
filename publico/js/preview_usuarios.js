// Función para cargar todas los usuarios desde el servidor
fetch('/users')
    .then(response => response.json())
    .then(data => {
        const contenedor = document.getElementById('preview_usuarios');

        // Si el servidor responde con datos
        if (data && data.length > 0) {
            // 1. Quitamos el mensaje de "Reseñas en Preview"
            contenedor.innerHTML = ''; 

            // 2. Recorremos TODA la base de datos
            data.forEach(USERS => {
                // Creamos el elemento de la tarjeta
                const card = document.createElement('div');
                card.className = 'USERS-card';

                const NAME = document.createElement('h4');
                NAME.textContent = USERS.name;

                const boton_e = document.createElement('button');
                boton_e.className = 'btn btn-success w-100 mt-auto';
                boton_e.textContent = 'editar usuario';
                boton_e.name = "btnEU";
                boton_e.value = USERS._id;

                const boton_d = document.createElement('button');
                boton_d.className = 'btn btn-success w-100 mt-auto';
                boton_d.textContent = 'borrar usuario';
                boton_d.name = "btnDU";
                boton_d.value = USERS._id;

                // Ensamblar la tarjeta

                card.appendChild(NAME);
                card.appendChild(boton_e);
                card.appendChild(boton_d);

                // Agregar al contenedor principal
                contenedor.appendChild(card);
            });
        } else {
            contenedor.innerHTML = '<div class="mensaje-espera"><p>No hay reseñas disponibles actualmente.</p></div>';
        }
    })
    .catch(error => {
        console.error('Error al conectar con el servidor:', error);
        const contenedor = document.getElementById('preview_usuarios');
        contenedor.innerHTML = '<div class="mensaje-espera text-danger"><p>Error al cargar los datos del servidor.</p></div>';
    });