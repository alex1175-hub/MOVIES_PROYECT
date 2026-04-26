const express = require('express');
const path = require('path');
const mongoose = require('mongoose');
const multer = require('multer');
const fs = require('fs');
const sharp = require('sharp');
const crypto = require('crypto'); 

const app = express();


// ==============================
// CONFIGURACIÓN GENERAL
// ==============================

// Servir archivos estáticos
app.use(express.static(path.join(__dirname, 'publico')));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const PORT = 8080;


// ==============================
// FUNCIÓN HASH SHA256 
// ==============================

function sha256(texto) {
    return crypto
        .createHash('sha256')
        .update(String(texto))
        .digest('hex');
}


// ==============================
// CONEXIÓN A MONGODB
// ==============================

mongoose.connect('mongodb://127.0.0.1:27017/TIRN_BD')
    .then(() => console.log('Conectado a MongoDB'))
    .catch(err => console.error(err));


// ==============================
// MODELOS
// ==============================

const MovieSchema = new mongoose.Schema({
    name: String,
    year: Number,
    director: String,
    review: String,
    actors: [String],
    imageUrl: String
});

const UserSchema = new mongoose.Schema({
    name: String,
    contra: String, // aquí se guarda el hash
    email: String,
    rank: String
});

const Movie = mongoose.model('Movies', MovieSchema, 'Movies');
const User = mongoose.model('Users', UserSchema, 'Users');


// ==============================
// FUNCIÓN PARA LIMPIAR NOMBRE
// ==============================

function limpiarNombre(nombre) {
    return nombre
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .toLowerCase()
        .trim()
        .replace(/\s+/g, '-')
        .replace(/[^\w-]/g, '');
}


// ==============================
// RUTAS GENERALES
// ==============================

// Obtener lista simple de películas
app.get('/movies', async (req, res) => {
    try {
        const movies = await Movie.find({}, '_id name');

        res.json(movies);

    } catch (error) {
        res.status(500).json({
            error: 'Error al obtener películas'
        });
    }
});

// Obtener lista simple de usuarios
app.get('/users', async (req, res) => {
    try {
        const users = await User.find({}, '_id name');

        res.json(users);

    } catch (error) {
        res.status(500).json({
            error: 'Error al obtener usuarios'
        });
    }
});


// ==============================
// LOGIN 
// ==============================

app.post('/api/login', async (req, res) => {
    let { name, pass } = req.body;

    try {
        const passHash = sha256(pass);

        const usuario = await User.findOne(
            {
                name: name,
                contra: passHash
            },
            '_id rank'
        );

        if (usuario) {
            return res.json({
                success: true,
                user: {
                    id: usuario._id,
                    rank: usuario.rank
                }
            });
        }

        res.json({
            success: false,
            message: 'Credenciales incorrectas'
        });

    } catch (error) {
        console.error(error);

        res.status(500).json({
            success: false,
            message: 'Error en el servidor'
        });
    }
});


// ============================== 
// REGISTRO
// ==============================

app.post('/api/registro', async (req, res) => {
    let { name, email, pass, rank } = req.body;

    try {
        // Verificar si ya existe
        const existe = await User.findOne({
            $or: [
                { name: name },
                { email: email }
            ]
        });

        if (existe) {
            return res.json({
                success: false,
                message: 'El usuario ya existe'
            });
        }

        // Hash de contraseña en backend
        const passHash = sha256(pass);

        const nuevoUsuario = new User({
            name: name,
            email: email,
            contra: passHash,
            rank: rank || 'user'
        });

        await nuevoUsuario.save();

        res.json({
            success: true,
            message: 'Usuario registrado correctamente'
        });

    } catch (error) {
        console.error(error);

        res.status(500).json({
            success: false,
            message: 'Error en el servidor'
        });
    }
});


// ==============================
// PELÍCULAS - CONSULTAR
// ==============================

// Obtener película por ID
app.get('/api/movie/:id', async (req, res) => {
    const { id } = req.params;

    try {
        const movie = await Movie.findById(id);

        if (!movie) {
            return res.json({
                success: false,
                message: 'Película no encontrada'
            });
        }

        res.json({
            success: true,
            movie: movie
        });

    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Error en el servidor'
        });
    }
});

// Buscar película por nombre
app.get('/api/movie/name/:name', async (req, res) => {
    try {
        const movie = await Movie.findOne({
            name: new RegExp(req.params.name, 'i')
        });

        if (!movie) {
            return res.json({
                success: false,
                message: 'Película no encontrada'
            });
        }

        res.json({
            success: true,
            movie: movie
        });

    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Error en el servidor'
        });
    }
});


// ==============================
// CONFIGURACIÓN DE IMÁGENES
// ==============================

const uploadDir = path.join(__dirname, 'publico', 'imagenes');

if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
}

const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 10 * 1024 * 1024
    }
});

app.use(
    '/imagenes',
    express.static(path.join(__dirname, 'publico', 'imagenes'))
);


// ==============================
// CREAR PELÍCULA
// ==============================

app.post('/api/movies', upload.single('image'), async (req, res) => {
    try {
        const { name, year, director, review, actors } = req.body;

        const nombreLimpio = limpiarNombre(name);
        let imageUrl = null;

        if (req.file) {
            const rutaFinal = path.join(
                uploadDir,
                `${nombreLimpio}.png`
            );

            await sharp(req.file.buffer)
                .png()
                .toFile(rutaFinal);

            imageUrl = `/imagenes/${nombreLimpio}.png`;
        }

        const nuevaMovie = new Movie({
            name,
            year: Number(year),
            director,
            review,
            actors: actors.split(',').map(a => a.trim()),
            imageUrl
        });

        await nuevaMovie.save();

        res.json({
            success: true,
            message: "Película guardada correctamente"
        });

    } catch (error) {
        console.error(error);

        res.json({
            success: false,
            message: error.message
        });
    }
});


// ==============================
// EDITAR PELÍCULA
// ==============================

app.put('/api/movies/:id', upload.single('image'), async (req, res) => {
    try {
        const nombreLimpio = limpiarNombre(req.body.name);

        const updateData = {
            name: req.body.name,
            year: Number(req.body.year),
            director: req.body.director,
            review: req.body.review,
            actors: req.body.actors.split(',').map(a => a.trim())
        };

        if (req.file) {
            const rutaFinal = path.join(
                uploadDir,
                `${nombreLimpio}.png`
            );

            await sharp(req.file.buffer)
                .png()
                .toFile(rutaFinal);

            updateData.imageUrl = `/imagenes/${nombreLimpio}.png`;
        }

        const movie = await Movie.findByIdAndUpdate(
            req.params.id,
            updateData,
            { new: true }
        );

        if (!movie) {
            return res.json({
                success: false,
                message: "Película no encontrada"
            });
        }

        res.json({
            success: true,
            message: "Película actualizada correctamente"
        });

    } catch (error) {
        console.error(error);

        res.json({
            success: false,
            message: error.message
        });
    }
});


// ==============================
// ELIMINAR PELÍCULA
// ==============================

app.delete('/api/movies/:id', async (req, res) => {
    try {
        const movie = await Movie.findById(req.params.id);

        if (!movie) {
            return res.json({
                success: false,
                message: "Película no encontrada"
            });
        }

        if (movie.imageUrl) {
            const imagePath = path.join(
                __dirname,
                'publico',
                movie.imageUrl.replace('/imagenes/', 'imagenes/')
            );

            if (fs.existsSync(imagePath)) {
                fs.unlinkSync(imagePath);
            }
        }

        await Movie.findByIdAndDelete(req.params.id);

        res.json({
            success: true,
            message: "Película eliminada correctamente"
        });

    } catch (error) {
        console.error(error);

        res.json({
            success: false,
            message: error.message
        });
    }
});
// ==============================
// ADMIN - NUEVO USUARIO
// ==============================

app.post('/api/admin_nu', async (req, res) => {
    let { name, email, pass, rank } = req.body;

    try {
        // ==============================
        // VALIDAR EXISTENCIA
        // ==============================

        const existe = await User.findOne({
            $or: [
                { name: name },
                { email: email }
            ]
        });

        if (existe) {
            return res.json({
                success: false,
                message: 'El usuario ya existe'
            });
        }

        const passHash = sha256(pass);

        // ==============================
        // CREAR USUARIO
        // ==============================

        const nuevoUsuario = new User({
            name: name,
            email: email,
            contra: passHash,
            rank: rank
        });

        await nuevoUsuario.save();

        res.json({
            success: true,
            message: 'Usuario creado correctamente'
        });

    } catch (error) {
        console.error(error);

        res.status(500).json({
            success: false,
            message: 'Error en el servidor'
        });
    }
});

// ==============================
// OBTENER USUARIO POR ID
// ==============================

app.get('/api/user/:id', async (req, res) => {
    const { id } = req.params;

    try {
        // Buscar usuario por ID
        // NO se devolve la contraseña
        const user = await User.findById(
            id,
            '_id name email rank'
        );

        if (!user) {
            return res.json({
                success: false,
                message: 'Usuario no encontrado'
            });
        }

        res.json({
            success: true,
            user: {
                id: user._id,
                name: user.name,
                email: user.email,
                rank: user.rank
            }
        });

    } catch (error) {
        console.error(error);

        res.status(500).json({
            success: false,
            message: 'Error en el servidor'
        });
    }
});

// ==============================
// ADMIN - EDITAR USUARIO
// ==============================

app.post('/api/edit_user', async (req, res) => {
    let { id, name, email, pass, rank } = req.body;

    try {
        // ==============================
        // VALIDAR USUARIO EXISTENTE
        // ==============================

        const usuario = await User.findById(id);

        if (!usuario) {
            return res.json({
                success: false,
                message: 'Usuario no encontrado'
            });
        }

        // ==============================
        // BLOQUEAR EDICIÓN SI ES MASTER
        // ==============================

        if (usuario.rank === 'master') {
            return res.json({
                success: false,
                message: 'No se puede editar un usuario con rango master'
            });
        }

        // ==============================
        // VALIDAR DUPLICADOS
        // ==============================

        const duplicado = await User.findOne({
            _id: { $ne: id }, // excluir el mismo usuario
            $or: [
                { name: name },
                { email: email }
            ]
        });

        if (duplicado) {
            return res.json({
                success: false,
                message: 'Ya existe otro usuario con ese nombre o email'
            });
        }

        // ==============================
        // DATOS BASE
        // ==============================

        const updateData = {
            name: name,
            email: email,
            rank: rank
        };

        // ==============================
        // SI HAY NUEVA CONTRASEÑA
        // ==============================

        if (pass && pass.trim() !== '') {
            updateData.contra = sha256(pass);
        }

        // ==============================
        // ACTUALIZAR
        // ==============================

        await User.findByIdAndUpdate(
            id,
            updateData,
            { new: true }
        );

        res.json({
            success: true,
            message: 'Usuario editado correctamente'
        });

    } catch (error) {
        console.error(error);

        res.status(500).json({
            success: false,
            message: 'Error en el servidor'
        });
    }
});

// ==============================
// ADMIN - ELIMINAR USUARIO
// ==============================

app.post('/api/delete_user', async (req, res) => {
    const { id } = req.body;

    try {
        // ==============================
        // VALIDAR ID
        // ==============================

        if (!id) {
            return res.json({
                success: false,
                message: 'ID de usuario no recibido'
            });
        }

        // ==============================
        // BUSCAR USUARIO
        // ==============================

        const usuario = await User.findById(id);

        if (!usuario) {
            return res.json({
                success: false,
                message: 'Usuario no encontrado'
            });
        }

        // ==============================
        // BLOQUEAR ELIMINACIÓN SI ES MASTER
        // ==============================

        if (usuario.rank === 'master') {
            return res.json({
                success: false,
                message: 'No se puede eliminar un usuario con rango master'
            });
        }

        // ==============================
        // ELIMINAR USUARIO
        // ==============================

        await User.findByIdAndDelete(id);

        res.json({
            success: true,
            message: 'Usuario eliminado correctamente'
        });

    } catch (error) {
        console.error(error);

        res.status(500).json({
            success: false,
            message: 'Error en el servidor'
        });
    }
});


// ==============================
// INICIAR SERVIDOR
// ==============================

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Servidor corriendo en:`);
    console.log(`Local: http://localhost:${PORT}`);
    console.log(`Red: http://192.168.56.1:${PORT}`);
});