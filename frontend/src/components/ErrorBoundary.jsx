// Captura cualquier error de render y muestra un aviso en vez de dejar la
// pantalla en negro. Permite reintentar sin recargar toda la app.
import { Component } from "react";

export default class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { error: null };
  }
  static getDerivedStateFromError(error) {
    return { error };
  }
  reset = () => this.setState({ error: null });

  render() {
    if (this.state.error) {
      return (
        <div className="card" style={{ margin: 24 }}>
          <h3 className="page-title">Algo salio mal en esta pantalla</h3>
          <p className="muted">{String(this.state.error?.message || this.state.error)}</p>
          <button className="btn btn-primary" onClick={this.reset}>Reintentar</button>
        </div>
      );
    }
    return this.props.children;
  }
}
