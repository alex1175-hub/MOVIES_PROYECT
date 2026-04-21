
function mostrarBusquedaEditar() {
    document.getElementById('editarBox').style.display = 'block';
}

// ================= CREAR 
async function guardarResena() {

    const name = document.getElementById('movieName').value.trim();
    const year = document.getElementById('movieYear').value.trim();
    const director = document.getElementById('movieDirector').value.trim();
    const review = document.getElementById('movieReview').value.trim();
    const actors = document.getElementById('movieActors').value.trim();

    //  VALIDACIÓN
    if (!name || !year || !director || !review || !actors) {
        alert("Todos los campos son obligatorios");
        return; //  detiene todo
    }

    const nueva = {
        name: name,
        year: Number(year),
        director: director,
        review: review,
        actors: actors.split(',').map(a => a.trim())
    };

    try {
        const res = await fetch('/api/movies', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(nueva)
        });

        const data = await res.json();

        if (data.success) {
            alert("Película guardada correctamente");
            limpiarFormulario();
        } else {
            alert(data.message);
        }

    } catch (error) {
        console.error(error);
        alert("Error al conectar con el servidor");
    }
}
// ================= EDITAR
async function editarDesdeFormulario() {

    const id = window.idEditar;

    if (!id) {
        alert("Primero busca una película");
        return;
    }

    const actualizada = {
        name: document.getElementById('movieName').value,
        year: parseInt(document.getElementById('movieYear').value),
        director: document.getElementById('movieDirector').value,
        review: document.getElementById('movieReview').value,
        actors: document.getElementById('movieActors').value.split(',')
    };

    const res = await fetch(`/api/movies/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(actualizada)
    });

    const data = await res.json();
    alert(data.message);
}

async function buscarYEditar() {

    const nombre = document.getElementById('nombreBuscar').value;

    if (!nombre) {
        alert("Escribe el nombre");
        return;
    }

    //  Buscar en backend
    const resBuscar = await fetch(`/api/movie/name/${nombre}`);
    const data = await resBuscar.json();

    if (!data.success) {
        alert("Película no encontrada");
        return;
    }

    const movie = data.movie;

    //  Autollenar formulario
    document.getElementById('movieName').value = movie.name;
    document.getElementById('movieYear').value = movie.year;
    document.getElementById('movieDirector').value = movie.director;
    document.getElementById('movieReview').value = movie.review;
    document.getElementById('movieActors').value = movie.actors.join(',');

    //  Guardar ID para usarlo después
    window.idEditar = movie._id;

    alert("Película cargada, ahora edítala y haz clic en Guardar cambios");
}

async function guardarCambios() {

    if (!window.idEditar) {
        alert("Primero busca una película");
        return;
    }

    const actualizada = {
        name: document.getElementById('movieName').value,
        year: parseInt(document.getElementById('movieYear').value),
        director: document.getElementById('movieDirector').value,
        review: document.getElementById('movieReview').value,
        actors: document.getElementById('movieActors').value.split(',')
    };

    const res = await fetch(`/api/movies/${window.idEditar}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(actualizada)
    });

    const data = await res.json();

    alert(data.message);

    //  LIMPIAR TODO
    limpiarFormulario();
}

// ================= LIMPIAR FORMULARIO
function limpiarFormulario() {
    document.getElementById('movieName').value = '';
    document.getElementById('movieYear').value = '';
    document.getElementById('movieDirector').value = '';
    document.getElementById('movieReview').value = '';
    document.getElementById('movieActors').value = '';

    if (document.getElementById('nombreBuscar')) {
        document.getElementById('nombreBuscar').value = '';
    }

    window.idEditar = null;
}

// ================= ELIMINAR
async function eliminarResena() {

    //  usar el ID de la película buscada
    const id = window.idEditar;

    if (!id) {
        alert("Primero busca una película");
        return;
    }

    if (!confirm("¿Eliminar esta reseña?")) return;

    const res = await fetch(`/api/Movies/${id}`, { //  corregido (minúsculas)
        method: 'DELETE'
    });

    const data = await res.json();

    alert(data.message);

    // 🧹 limpiar después de eliminar
    limpiarFormulario();
}