import { statusText } from "./api-client.js";

export default function Status({ status }) {
  return <span className={`status status-${status.toLowerCase()}`}><i />{statusText[status]}</span>;
}
