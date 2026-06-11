export default async function Login({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;
  return (
    <main>
      <h1>Sign in</h1>
      {error ? (
        <p role="alert" style={{ color: "crimson" }}>
          Invalid username or password.
        </p>
      ) : null}
      <form method="post" action="/api/login">
        <p>
          <label>
            Username
            <br />
            <input name="username" autoComplete="username" required />
          </label>
        </p>
        <p>
          <label>
            Password
            <br />
            <input name="password" type="password" autoComplete="current-password" required />
          </label>
        </p>
        <button type="submit">Sign in</button>
      </form>
    </main>
  );
}
