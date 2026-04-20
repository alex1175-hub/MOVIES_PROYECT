const Rtitulo = document.getElementById('titulo');
const Rimagen = document.getElementById('imagen');
const Ranio = document.getElementById('anio');
const Rdirec = document.getElementById('direc');
const Rtext = document.getElementById('text');
const Ractor = document.getElementById('actor');

const id_r = localStorage.getItem('id_pr');

if (!id_r) {
    console.log("No se encontró el ID de la película");
} else {

    fetch(`/api/movie/${id_r}`)
        .then(response => response.json())
        .then(data => {

            if (!data.success) {
                console.log(data.message);
                return;
            }

            Rtitulo.textContent = data.movie.name;
            Rimagen.src = `/imagenes/${data.movie.name}.png`;
            Rimagen.alt = data.movie.Name;
            Rimagen.width = 180;
            Ranio.textContent = data.movie.year;
            Rdirec.textContent = data.movie.director;
            Rtext.textContent = data.movie.review;
            Ractor.innerHTML = '';
            console.log(data.movie);
            console.log("actors:", data.movie.actors);
            console.log("tipo:", typeof data.movie.actors);
            data.movie.actors.forEach(actor => {
                const li = document.createElement('li');
                li.textContent = actor;
                Ractor.appendChild(li);
            });

        })
        .catch(error => {
            console.error("Error:", error);
        });
}