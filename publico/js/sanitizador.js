class Sanitizador {
    constructor() {}
    // Limpiar texto general
    limpiarTexto(valor) {
        if (!valor) return '';

        return valor
            .toString()
            .trim()
            .replace(/\s+/g, ' ') // espacios múltiples → uno solo
            .replace(/[<>]/g, ''); // elimina < >
    }
    // Solo letras, números, espacios y algunos símbolos comunes
    limpiarSeguro(valor) {
        if (!valor) return '';
        return valor
            .toString()
            .trim()
            .replace(/[^a-zA-Z0-9áéíóúÁÉÍÓÚñÑ\s.,\-_/()[\]{}]/g, '');
    }
    // Convertir nombre de archivo seguro
    limpiarNombreArchivo(valor) {
        if (!valor) return '';
        return valor
            .toLowerCase()
            .trim()
            .normalize("NFD") // separa acentos
            .replace(/[\u0300-\u036f]/g, '') // elimina acentos
            .replace(/\s+/g, '-') // espacios → -
            .replace(/[^a-z0-9-_]/g, ''); // solo seguro para archivos
    }
    // Validar email básico
    limpiarEmail(valor) {
        if (!valor) return '';

        valor = valor.toString().trim().toLowerCase();

        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

        return emailRegex.test(valor) ? valor : '';
    }
    // Solo números
    limpiarNumero(valor) {
        if (!valor) return '';

        return valor.toString().replace(/\D/g, '');
    }
    // Lista separada por comas (actores)
    limpiarLista(valor) {
        if (!valor) return '';

        return valor
            .split(',')
            .map(item => this.limpiarSeguro(item))
            .filter(item => item !== '')
            .join(', ');
    }
}
const sanitizer = new Sanitizador();