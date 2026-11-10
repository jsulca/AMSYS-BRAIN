Console.WriteLine(args.Length > 1 && args[1] == "sha" ? AMSYS.Utilitarios.CriptografiaUtilitario.ToSHA526(args[0]) : AMSYS.Utilitarios.ClaveUtilitario.Hash(args[0]));
