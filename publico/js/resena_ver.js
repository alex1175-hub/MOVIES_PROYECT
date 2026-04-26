const previewContainer = document.getElementById('preview');

previewContainer.addEventListener('click', async function(event) {
    if (event.target && event.target.name === 'ver') {
        const Did = event.target.value;

        localStorage.setItem('id_pr', Did);

        window.location.href = '/resena_v.html';
    }
});