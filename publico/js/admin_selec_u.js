const cajaid = document.getElementById('preview_usuarios');
cajaid.addEventListener('click', async function(event) {
    if (event.target && event.target.name === 'btnEU') {
        const Did = event.target.value;
        console.log(Did);
        localStorage.setItem('id_ue', Did);
        window.location.href = '/admin_eu.html';
    }
});