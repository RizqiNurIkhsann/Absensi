<?php
namespace App\Http\Controllers;
use Illuminate\Http\Request;
use App\Models\Jabatan;

class JabatanController extends Controller {
    public function index() { return response()->json(['data' => Jabatan::all()]); }
    public function store(Request $request) { return response()->json(['data' => Jabatan::create($request->all())], 201); }
    public function update(Request $request, $id) { $model = Jabatan::findOrFail($id); $model->update($request->all()); return response()->json(['data' => $model]); }
    public function destroy($id) { Jabatan::destroy($id); return response()->json(['message' => 'Deleted']); }
}
