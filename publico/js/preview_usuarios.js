let contenedorUsuarios = document.getElementById('preview_usuarios');

// Estado de filtro (si después agregas búsqueda de usuarios)
let filtroUsuariosActivo = false;

// =====================================
// CREAR TARJETAS DE USUARIOS
// =====================================
function crearUsuarios(data) {
    contenedorUsuarios.innerHTML = '';

    if (!data || data.length === 0) {
        contenedorUsuarios.innerHTML = `
            <div class="mensaje-espera">
                <p>No hay usuarios disponibles actualmente.</p>
            </div>
        `;
        return;
    }

    data.forEach(USERS => {

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

        card.appendChild(NAME);
        card.appendChild(boton_e);
        card.appendChild(boton_d);

        contenedorUsuarios.appendChild(card);
    });
}

// =====================================
// CARGAR USUARIOS
// =====================================
function cargarUsuarios() {

    // ❗ NO actualizar si hay filtro activo
    if (filtroUsuariosActivo) return;

    fetch('/users')
        .then(response => response.json())
        .then(data => {
            crearUsuarios(data);
        })
        .catch(error => {
            console.error('Error al conectar con el servidor:', error);

            contenedorUsuarios.innerHTML = `
                <div class="mensaje-espera text-danger">
                    <p>Error al cargar los datos del servidor.</p>
                </div>
            `;
        });
}

// =====================================
// CARGA INICIAL + AUTO REFRESH 5s
// =====================================
cargarUsuarios();
setInterval(cargarUsuarios, 5000);