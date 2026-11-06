package plugin.google.maps;

import android.os.AsyncTask;
import android.util.Log;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.HashMap;
import java.util.Map;

public class AsyncPostJsonWithURL extends AsyncTask<HashMap<String, Object>, Void, JSONObject> {
  private AsyncHttpPostInterface callback;
  private final String TAG = "AsyncHttpPost";
  private String BASE_URI = "";
  private Map<String, String> headers = new HashMap<String, String>();

  public interface AsyncHttpPostInterface {
    void onPostExecute(JSONObject result);
  }

  public AsyncPostJsonWithURL(String baseUri, AsyncHttpPostInterface callback) {
    this.callback = callback;
    this.BASE_URI = baseUri;
  }

  public void setHeader(String key, String value) {
    headers.put(key, value);
  }

  protected JSONObject doInBackground(HashMap<String, Object>... params) {
    try {
      URL url = new URL(BASE_URI);
      HttpURLConnection http = (HttpURLConnection) url.openConnection();
      http.setRequestMethod("POST");
      http.setDoOutput(true);
      http.setUseCaches(false);
      http.setRequestProperty("Content-Type", "application/json");
      http.setRequestProperty("Accept", "application/json");
      http.addRequestProperty("Accept-Language", "en-US,en;q=0.8");
      http.addRequestProperty("User-Agent", "Mozilla");

      // Set custom headers (e.g., X-Goog-Api-Key, X-Goog-FieldMask)
      for (Map.Entry<String, String> entry : headers.entrySet()) {
        http.setRequestProperty(entry.getKey(), entry.getValue());
      }

      // Write JSON request body
      HashMap<String, Object> body = params[0];
      JSONObject jsonBody = new JSONObject(body);
      byte[] postData = jsonBody.toString().getBytes("UTF-8");
      http.setRequestProperty("Content-Length", String.valueOf(postData.length));
      OutputStream os = http.getOutputStream();
      os.write(postData);
      os.flush();
      os.close();

      int status = http.getResponseCode();
      String responseBody = null;
      InputStream inputStream;

      if (status != HttpURLConnection.HTTP_OK) {
        // Read error response body from Places API (New)
        inputStream = http.getErrorStream();
        if (inputStream != null) {
          ByteArrayOutputStream buffer = new ByteArrayOutputStream();
          int nRead;
          byte[] data = new byte[16384];
          while ((nRead = inputStream.read(data, 0, data.length)) != -1) {
            buffer.write(data, 0, nRead);
          }
          buffer.flush();
          inputStream.close();
          responseBody = buffer.toString("UTF-8");
        }
        Log.e(TAG, "HTTP error: " + status + ", body: " + responseBody);
        // Return a JSON object with the error details so the caller can pass them through
        JSONObject errorResult = new JSONObject();
        errorResult.put("_httpStatus", status);
        if (responseBody != null) {
          try {
            errorResult.put("_errorBody", new JSONObject(responseBody));
          } catch (Exception e) {
            errorResult.put("_errorBody", responseBody);
          }
        }
        return errorResult;
      }

      inputStream = http.getInputStream();
      ByteArrayOutputStream buffer = new ByteArrayOutputStream();
      int nRead;
      byte[] data = new byte[16384];
      while ((nRead = inputStream.read(data, 0, data.length)) != -1) {
        buffer.write(data, 0, nRead);
      }
      buffer.flush();
      inputStream.close();
      return new JSONObject(buffer.toString());
    } catch (Exception e) {
      Log.e(TAG, "can not connect to " + BASE_URI, e);
      return null;
    }
  }

  @Override
  protected void onPostExecute(JSONObject result) {
    this.callback.onPostExecute(result);
  }
}