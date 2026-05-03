<?php
namespace App\Http\Controllers;
use Illuminate\Http\Request;
use App\Models\Departemen;

class DepartemenController extends Controller {
    public function index() { return response()->json(['data' => Departemen::all()]); }
    public function store(Request $request) { return response()->json(['data' => Departemen::create($request->all())], 201); }
    public function update(Request $request, $id) { $model = Departemen::findOrFail($id); $model->update($request->all()); return response()->json(['data' => $model]); }
    public function destroy($id) { Departemen::destroy($id); return response()->json(['message' => 'Deleted']); }
}
