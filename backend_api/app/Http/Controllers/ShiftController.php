<?php
namespace App\Http\Controllers;
use Illuminate\Http\Request;
use App\Models\Shift;

class ShiftController extends Controller {
    public function index() { return response()->json(['data' => Shift::all()]); }
    public function store(Request $request) { return response()->json(['data' => Shift::create($request->all())], 201); }
    public function update(Request $request, $id) { $model = Shift::findOrFail($id); $model->update($request->all()); return response()->json(['data' => $model]); }
    public function destroy($id) { Shift::destroy($id); return response()->json(['message' => 'Deleted']); }
}
