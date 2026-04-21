const contenedor = document.getElementById('preview');
contenedor.addEventListener('click', async function(event) {
    if (event.target && event.target.name === 'ver') {
        const Did = event.target.value;
        //console.log(Did);
        localStorage.setItem('id_pr', Did);
        window.location.href = '/resena_v.html';
    }
});