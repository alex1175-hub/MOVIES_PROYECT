// ==============================
// MOSTRAR CAJA DE EDICIÓN
// ==============================
function mostrarBusquedaEditar() {
    const editarBox = document.getElementById('editarBox');

    if (editarBox) {
        editarBox.style.display = 'block';
    }
}

// ==============================
// CREAR RESEÑA (CON IMAGEN)
// ==============================
async function guardarResena() {
    let name = document.getElementById('movieName').value.trim();
    let year = document.getElementById('movieYear').value.trim();
    let director = document.getElementById('movieDirector').value.trim();
    let review = document.getElementById('movieReview').value.trim();
    let actors = document.getElementById('movieActors').value.trim();
    const imageFile = document.getElementById('movieImage').files[0];
    name = sanitizer.limpiarSeguro(name);
    year = sanitizer.limpiarNumero(year);
    director = sanitizer.limpiarSeguro(director);
    review = sanitizer.limpiarTexto(review);
    actors = sanitizer.limpiarLista(actors);

    // VALIDACIÓN
    if (!name || !year || !director || !review || !actors) {
        alert("Todos los campos son obligatorios");
        return;
    }

    // FormData para enviar archivo + datos
    const formData = new FormData();
    formData.append('name', name);
    formData.append('year', Number(year));
    formData.append('director', director);
    formData.append('review', review);
    formData.append('actors', actors);

    if (imageFile) {
        formData.append('image', imageFile);
    }

    try {
        const res = await fetch('/api/movies', {
            method: 'POST',
            body: formData
        });

        const data = await res.json();

        if (data.success) {
            alert("Película guardada correctamente");
            limpiarFormulario();
        } else {
            alert(data.message || "No se pudo guardar la película");
        }

    } catch (error) {
        console.error(error);
        alert("Error al conectar con el servidor");
    }
}

// ==============================
// BUSCAR PELÍCULA PARA EDITAR
// ==============================
async function buscarYEditar() {
    const nombre = document.getElementById('nombreBuscar').value.trim();

    if (!nombre) {
        alert("Escribe el nombre de la película");
        return;
    }

    try {
        const resBuscar = await fetch(`/api/movie/name/${encodeURIComponent(nombre)}`);
        const data = await resBuscar.json();

        if (!data.success) {
            alert("Película no encontrada");
            return;
        }

        const movie = data.movie;

        // Autollenar formulario
        document.getElementById('movieName').value = movie.name || '';
        document.getElementById('movieYear').value = movie.year || '';
        document.getElementById('movieDirector').value = movie.director || '';
        document.getElementById('movieReview').value = movie.review || '';
        document.getElementById('movieActors').value =
            movie.actors ? movie.actors.join(', ') : '';

        // Mostrar imagen actual
        const imagePreview = document.getElementById('currentImagePreview');

        if (imagePreview) {
            if (movie.imageUrl) {
                imagePreview.innerHTML = `
                    <img 
                        src="${movie.imageUrl}" 
                        width="150"
                        class="img-thumbnail me-2 mb-2"
                    >
                    <div>
                        <small class="text-muted">
                            Imagen actual guardada
                        </small>
                    </div>
                `;

                imagePreview.style.display = 'block';
            } else {
                imagePreview.innerHTML = '';
                imagePreview.style.display = 'none';
            }
        }

        // Guardar ID global para editar/eliminar
        window.idEditar = movie._id;

        // Mostrar aviso visual
        mostrarBusquedaEditar();

        alert("Película cargada correctamente.\nAhora puedes editar y guardar cambios.");

    } catch (error) {
        console.error(error);
        alert("Error al buscar la película");
    }
}

// ==============================
// GUARDAR CAMBIOS (EDITAR)
// ==============================
async function guardarCambios() {
    if (!window.idEditar) {
        alert("Primero busca una película para editar");
        return;
    }

    let name = document.getElementById('movieName').value.trim();
    let year = document.getElementById('movieYear').value.trim();
    let director = document.getElementById('movieDirector').value.trim();
    let review = document.getElementById('movieReview').value.trim();
    let actors = document.getElementById('movieActors').value.trim();
    const imageFile = document.getElementById('movieImage').files[0];
    name = sanitizer.limpiarSeguro(name);
    year = sanitizer.limpiarNumero(year);
    director = sanitizer.limpiarSeguro(director);
    review = sanitizer.limpiarTexto(review);
    actors = sanitizer.limpiarLista(actors);

    // VALIDACIÓN
    if (!name || !year || !director || !review || !actors) {
        alert("Todos los campos son obligatorios");
        return;
    }

    const formData = new FormData();
    formData.append('name', name);
    formData.append('year', Number(year));
    formData.append('director', director);
    formData.append('review', review);
    formData.append('actors', actors);

    // Si selecciona nueva imagen, se reemplaza
    if (imageFile) {
        formData.append('image', imageFile);
    }

    try {
        const res = await fetch(`/api/movies/${window.idEditar}`, {
            method: 'PUT',
            body: formData
        });

        const data = await res.json();

        if (data.success) {
            alert("Película actualizada correctamente");
            limpiarFormulario();
        } else {
            alert(data.message || "No se pudo actualizar");
        }

    } catch (error) {
        console.error(error);
        alert("Error al conectar con el servidor");
    }
}

// ==============================
// ELIMINAR RESEÑA
// ==============================
async function eliminarResena() {
    if (!window.idEditar) {
        alert("Primero busca una película para eliminar");
        return;
    }

    const confirmar = confirm("¿Estás seguro de eliminar esta película?");

    if (!confirmar) return;

    try {
        const res = await fetch(`/api/movies/${window.idEditar}`, {
            method: 'DELETE'
        });

        const data = await res.json();

        if (data.success) {
            alert("Película eliminada correctamente");
            limpiarFormulario();
        } else {
            alert(data.message || "No se pudo eliminar");
        }

    } catch (error) {
        console.error(error);
        alert("Error al conectar con el servidor");
    }
}

// ==============================
// LIMPIAR FORMULARIO
// ==============================
function limpiarFormulario() {
    document.getElementById('movieName').value = '';
    document.getElementById('movieYear').value = '';
    document.getElementById('movieDirector').value = '';
    document.getElementById('movieReview').value = '';
    document.getElementById('movieActors').value = '';
    document.getElementById('nombreBuscar').value = '';

    // limpiar input file
    const imageInput = document.getElementById('movieImage');

    if (imageInput) {
        imageInput.value = '';
    }

    // ocultar preview
    const imagePreview = document.getElementById('currentImagePreview');

    if (imagePreview) {
        imagePreview.innerHTML = '';
        imagePreview.style.display = 'none';
    }

    // ocultar caja edición
    const editarBox = document.getElementById('editarBox');

    if (editarBox) {
        editarBox.style.display = 'none';
    }

    // limpiar ID global
    window.idEditar = null;
}