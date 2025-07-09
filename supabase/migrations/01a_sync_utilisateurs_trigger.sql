-- 1. Crée une fonction qui insère dans 'utilisateurs' à chaque création d'user
CREATE OR REPLACE FUNCTION public.sync_utilisateurs_on_signup()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.utilisateurs (id, email, created_at)
  VALUES (NEW.id, NEW.email, NOW())
  ON CONFLICT (id) DO NOTHING; -- évite les doublons si tu fais des imports massifs
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Crée le trigger sur la table auth.users
DROP TRIGGER IF EXISTS trg_sync_utilisateurs ON auth.users;
CREATE TRIGGER trg_sync_utilisateurs
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.sync_utilisateurs_on_signup();

