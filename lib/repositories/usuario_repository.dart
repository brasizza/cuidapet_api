import 'package:cuidapet_api/config/database_connection.dart';
import 'package:cuidapet_api/controllers/login/dto/login_patch_rq.dart';
import 'package:cuidapet_api/exceptions/user_notfound_exception.dart';
import 'package:cuidapet_api/models/usuario_model.dart';
import 'package:cuidapet_api/utils/cripty_utils.dart';
import 'package:cuidapet_api/utils/jwt_utils.dart';
import 'package:mysql1/mysql1.dart';

class UsuarioRepository {
  Future<UsuarioModel> validateLogin(String email, String senha, {bool facebook = false}) async {
    MySqlConnection conn;

    try {
      conn = await DatabaseConnection.openConnection();
      Results result;
      if (facebook) {
        result = await conn.query("select * from usuario where email = ?", [email]);
      } else {
        result = await conn.query("select * from usuario where email = ? and senha = ?", [email, CriptyUtils.generateSHA256Hash(senha)]);
      }

      if (result.isEmpty) {
        throw UserNotFoundException(message: "Usuário ou senha inválidos");
      } else {
        final u = result.first;
        return UsuarioModel(
          id: u[0] as int,
        );
      }
    } on MySqlException catch (e) {
      print(e);
      rethrow;
    } finally {
      await conn?.close();
    }
  }

  Future<String> updateTokenUser(LoginPatchRq request, int usuarioId, String accessToken) async {
    MySqlConnection conn;

    try {
      String query = 'update usuario set ';
      final List<dynamic> params = [];
      final refreshToken = JwtUtils.refreshToken(accessToken);

      if (request.iosToken != null) {
        // deslogar usuário android
        query += ' ios_token = ? ';
        params.add(request.iosToken);
      } else {
        // deslogar usuário ios
        query += ' android_token = ? ';
        params.add(request.androidToken);
      }

      query += ',refresh_token = ? where id = ? ';

      params.add(refreshToken);
      params.add(usuarioId);

      conn = await DatabaseConnection.openConnection();
      await conn.query(query, params);

      return refreshToken;
    } on MySqlException catch (e) {
      print(e);
      rethrow;
    } finally {
      await conn?.close();
    }
  }

  Future<UsuarioModel> getById(int id) async {
    MySqlConnection conn;

    try {
      conn = await DatabaseConnection.openConnection();
      final result = await conn.query("select * from usuario where id = ?", [id]);
      if (result.isEmpty) {
        throw UserNotFoundException(message: "Usuário ou senha inválidos");
      } else {
        final u = result.first;
        return UsuarioModel(
          id: u[0] as int,
          email: u[1] as String,
          tipoCadastro: u[3] as String,
          iosToken: (u[4] as Blob).toString(),
          androidToken: (u[5] as Blob).toString(),
          refrehToken: (u[6] as Blob).toString(),
          imgAvatar: (u[7] as Blob).toString(),
        );
      }
    } on MySqlException catch (e) {
      print(e);
      rethrow;
    } finally {
      await conn?.close();
    }
  }

  Future<UsuarioModel> createFacebookUser(String email, String avatar) async {
    MySqlConnection conn;

    try {
      conn = await DatabaseConnection.openConnection();
      final result = await conn.query("insert usuario(email, tipo_cadastro, img_avatar) values(?, ?, ?)", [email, 'FACEBOOK', avatar]);
      final userId = result.insertId;
      return UsuarioModel(
        id: userId,
      );
    } on MySqlException catch (e) {
      print(e);
      rethrow;
    } finally {
      await conn?.close();
    }
  }

  Future<void> updatePassword(int id, String password) async {
    MySqlConnection conn;

    try {
      conn = await DatabaseConnection.openConnection();
      await conn.query("update usuario set senha = ? where id = ?", [CriptyUtils.generateSHA256Hash(password), id]);
    } on MySqlException catch (e) {
      print(e);
      rethrow;
    } finally {
      await conn?.close();
    }
  }
}
